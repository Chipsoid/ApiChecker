package ApiChecker::Core::Eve;

use utf8;
use POSIX;
use Modern::Perl;
use Data::Dumper;
use JSON::XS;
use YAML::Tiny;
use List::MoreUtils qw/ uniq /;

use ApiChecker::Core::Api;
use ApiChecker::Core::Utils qw( epoch2mydate );

use lib '/www/Games-EveOnline-API/lib';
use lib '/www/games-eveonline-evecentral/lib';
use Games::EveOnline::API;
use Games::EveOnline::EveCentral;
use Games::EveOnline::EveCentral::Request::MarketStat;

sub new {
    my $class = shift;
    my $db    = shift;
    my $api   = shift;
    
    $class = ref ($class) || $class;

    my $self;
    $self = {
        db  => $db,
        api => $api,
    };

    bless $self, $class;
    return $self;
}

sub get_moon_mats {
    my ( $self ) = @_;

    return $self->{db}->selectall_arrayref("
        SELECT typeID, typeName FROM evedeliveries.invTypes WHERE groupID = 427;
        ",{ Slice => {} });
}

sub set_moon_mat {
    my ( $self, $moon_id, $moon_mat_id ) = @_;

    my $location_id = $self->{db}->selectrow_array("SELECT solarSystemID FROM evedeliveries.mapDenormalize WHERE itemID = ?", undef, $moon_id);

    $self->{db}->do("INSERT INTO eve_moon_mats SET moon_item_id = ?, location_id = ?, mat_type_id = ? ON DUPLICATE KEY UPDATE mat_type_id = ?", undef, $moon_id, $location_id, $moon_mat_id, $moon_mat_id);

    return 1;
}

sub edit_moon_mat {
    my ( $self, $moon_id, $moon_mat_id ) = @_;
    $self->{db}->do("UPDATE eve_moon_mats SET mat_type_id = ? WHERE id = ?", undef, $moon_mat_id, $moon_id);

    return 1;
}

sub del_moon_mat {
    my ( $self, $moon_id ) = @_;
    $self->{db}->do("DELETE FROM eve_moon_mats WHERE id = ?", undef, $moon_id);

    return 1;
}

sub get_khown_moons {
    my ( $self ) = @_;

    return $self->{db}->selectall_arrayref("SELECT emm.*,
                    ( SELECT itemName FROM evedeliveries.mapDenormalize WHERE itemID = emm.moon_item_id ) as moon_name,
                    ( select constellationName from evedeliveries.mapConstellations where constellationID = 
                        (SELECT constellationID FROM evedeliveries.mapSolarSystems WHERE solarSystemID = emm.location_id )
                    ) as const_name,
                    ( select regionName from evedeliveries.mapRegions where regionID = 
                        (SELECT regionID FROM evedeliveries.mapSolarSystems WHERE solarSystemID = emm.location_id )
                    ) as region_name,
                    ( select solarSystemName from evedeliveries.mapSolarSystems where solarSystemID = emm.location_id ) as location_name,
                    ( SELECT typeName FROM evedeliveries.invTypes WHERE typeID = emm.mat_type_id AND emm.mat_type_id > 0  ) as moon_mat_name 
                    FROM eve_moon_mats emm", { Slice => {} });
}

sub find_moons {
    my ( $self, $name ) = @_;

    return [] unless $name;

    return $self->{db}->selectall_arrayref("
        select itemID, itemName from evedeliveries.mapDenormalize where groupID = 8 AND itemName LIKE '".$name."%';
        ", { Slice => {} });
}

sub set_character_info {
    my ( $self, $char_ids ) = @_;

    $char_ids ||= $self->_get_char_ids();

    foreach my $id (  @$char_ids ) {
        next unless $id;
        next unless $id =~ /\d{8,}/;

        my ( $key, $vcode ) = $self->{api}->get_by_char_id( $id );
        my $eapi;
        if ( $key && $vcode ) {
           $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );
        }
        else {
            $eapi = Games::EveOnline::API->new();
        }

        my $info = $eapi->character_info( character_id => $id );
        $self->{api}->add_api_log('character_info', $info, $key, $id );
        if ( $info->{character_id} && $info->{character_id} > 0 ) {
            $self->_update_character_info( $info );
            $self->_update_employment_history( $info );
        }
    }

    return 1;
}

sub get_character_info {
    my ( $self, %params ) = @_;

    return [] unless $params{data} || $params{fields};

    my $exclude_ids = $params{exclude_ids} || [];

    my $data   = $params{data};
    my $fields = $params{fields};

    my @char_ids;
    foreach my $row ( @$data ) {
        foreach my $fld ( @$fields ) {
            if ( defined $row->{$fld} && $row->{$fld} =~ /\d+/ ) {
                if ( $row->{$fld} =~ /,/ ) {
                    my @ids = split ',', $row->{$fld};
                    @char_ids = ( @char_ids, @ids ) unless @ids ~~ @$exclude_ids;
                } 
                else {
                    push @char_ids, $row->{$fld} unless $row->{$fld} ~~ @$exclude_ids;
                }
                 
            }
        }
    }

    @char_ids = uniq @char_ids;

    my $result;
    if ( scalar @char_ids > 0 ) {
        $result = $self->{db}->selectall_hashref(
            "SELECT * FROM character_info WHERE character_id IN (". join(',',@char_ids) .")", 'character_name', 
        );
    }

    return $result;
}

sub _get_char_ids {
    my ($self) = @_;

    my @all_char_ids;

    my $char_ids = $self->{db}->selectcol_arrayref("
         (SELECT aki.character_id
         FROM  api_key_info aki
         GROUP BY aki.character_id)
         UNION
         (SELECT contact_id as character_id
          FROM character_contacts
          WHERE contact_id NOT IN ( SELECT character_id FROM character_info )
          GROUP BY contact_id)
         UNION
        (SELECT sender_id as character_id
            FROM character_mails
            WHERE sender_id > 0 AND sender_id NOT IN ( SELECT character_id FROM character_info )
            GROUP BY sender_id)
         ;", undef );

    # my $char_ids = $self->{db}->selectcol_arrayref("(SELECT cn.character_id
    #      FROM  character_names cn
    #      LEFT JOIN character_info ci ON cn.character_id = ci.character_id         
    #      WHERE DATE_ADD( ci.cached_until, INTERVAL 3 HOUR ) < NOW( ) OR ci.cached_until IS NULL 
    #      GROUP BY cn.character_id)
    #      UNION
    #      (SELECT aki.character_id
    #      FROM  api_key_info aki
    #      GROUP BY aki.character_id)
    #      UNION
    #      (SELECT contact_id as character_id
    #       FROM character_contacts
    #       GROUP BY contact_id)
    #      UNION
    #      (SELECT client_id as character_id
    #         FROM character_wallet_transactions
    #         GROUP BY client_id)
    #     UNION
    #      (SELECT owner_id1 as character_id
    #         FROM character_wallet_journal
    #         WHERE owner_id1 > 0
    #         GROUP BY owner_id1)
    #     UNION
    #      (SELECT owner_id2 as character_id
    #         FROM character_wallet_journal
    #         WHERE owner_id2 > 0
    #         GROUP BY owner_id2)
    #     UNION
    #     (SELECT sender_id as character_id
    #         FROM character_mails
    #         WHERE sender_id > 0
    #         GROUP BY sender_id)
    #      ;", undef );

    @all_char_ids = uniq @$char_ids;
    return \@all_char_ids;
}

sub _update_employment_history {
    my ( $self, $info ) = @_;

    return if scalar keys %{ $info->{employment_history} } == 0;

    my $history = $self->{db}->selectcol_arrayref("SELECT record_id FROM employment_history WHERE character_id = ?", undef, $info->{character_id} );

    foreach my $rid ( keys %{ $info->{employment_history} } ) {
        next if $rid ~~ @$history;
        $self->{db}->do("
            INSERT INTO employment_history 
            ( record_id, character_id, corporation_id, start_date, cached_until)
            VALUES (?, ?, ?, ?, ?)" , undef, 
            $rid, 
            $info->{character_id}, 
            $info->{employment_history}->{$rid}->{corporation_id},
            $info->{employment_history}->{$rid}->{start_date}, 
            $info->{cached_until} );
    }

    return 1;
}

sub get_employment_history {
    my ( $self, $char_id ) = @_;

    return unless $char_id;

    return $self->{db}->selectall_arrayref("
            SELECT *, cn.name as name, IF( npc.corporationID = eh.corporation_id, 1, 0 ) as is_npc, cl.ticker
            FROM employment_history eh LEFT JOIN character_names cn ON cn.character_id = eh.corporation_id 
            LEFT JOIN evedeliveries.crpNPCCorporations npc ON npc.corporationID = eh.corporation_id
            LEFT JOIN corporation_list cl ON cl.corporation_id = eh.corporation_id
            WHERE eh.character_id = ? ORDER BY record_id DESC;", { Slice => {} }, $char_id ) || [];
}

sub _update_character_info {
    my ( $self, $info ) = @_;

    $self->{db}->do("DELETE FROM character_info WHERE character_id = ?", undef, $info->{character_id} );

    my $sql = "
        INSERT INTO character_info 
        (character_id, character_name, alliance_id, corporation_id, alliance, corporation, race, bloodline, skill_points, ship_type_id,
         account_balance, last_known_location, alliance_date, corporation_date, ship_type_name, security_status, cached_until)
        VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ";

    $self->{db}->do($sql, 
        undef, $info->{character_id}, $info->{character_name}, $info->{alliance_id} || 0, $info->{corporation_id} || 0, $info->{alliance} || '', $info->{corporation} || '', $info->{race}, $info->{bloodline}, $info->{skill_points} || 0, $info->{ship_type_id} || 0, $info->{account_balance} || 0, $info->{last_known_location} || '', $info->{alliance_date} || 0, $info->{corporation_date} || 0, $info->{ship_type_name} || '', $info->{security_status}, $info->{cached_until} );

    return 1;
}

sub _get_new_character_ids {
    my ( $self ) = @_;

    my $char_ids = $self->{db}->selectcol_arrayref("
        ( SELECT to_character_ids FROM character_mails cm WHERE to_character_ids > 0 AND to_character_ids NOT IN ( SELECT character_id FROM character_names ) GROUP BY to_character_ids )
        UNION
        (SELECT to_corp_or_alliance_id FROM character_mails WHERE to_corp_or_alliance_id > 0 AND to_corp_or_alliance_id NOT IN ( SELECT character_id FROM character_names )   GROUP by to_corp_or_alliance_id )
         UNION
        (SELECT issuer_id FROM character_contracts WHERE issuer_id > 0 AND issuer_id NOT IN ( SELECT character_id FROM character_names )   GROUP by issuer_id )
        UNION
        (SELECT issuer_corp_id FROM character_contracts WHERE issuer_corp_id > 0 AND issuer_corp_id NOT IN ( SELECT character_id FROM character_names )   GROUP by issuer_corp_id )
        UNION
        (SELECT assignee_id FROM character_contracts WHERE assignee_id > 0 AND assignee_id NOT IN ( SELECT character_id FROM character_names )   GROUP by assignee_id )
        UNION
        (SELECT acceptor_id FROM character_contracts WHERE acceptor_id > 0 AND acceptor_id NOT IN ( SELECT character_id FROM character_names )   GROUP by acceptor_id );" , undef );

    my $fmt_char_ids;
    foreach my $str ( @$char_ids ) {
        push @$fmt_char_ids, split( ',', $str );
    }
    
    return [ uniq @$fmt_char_ids ];
}

sub set_character_ids {
    my ( $self ) = @_;

    my $eapi = Games::EveOnline::API->new();

    my $ids = $self->_get_new_character_ids();

    return unless scalar @$ids;

    my $names = $eapi->character_name( ids => join(',', @$ids ) );

    $self->{api}->add_api_log('character_name', $names );
    my @values;
    foreach my $char_id ( keys %$names ) {
        next unless $char_id =~ /\d+/;

        $self->{db}->do("INSERT INTO character_names (character_id, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = name", undef, $char_id, $names->{$char_id} );
    }

    return 1;
}

sub set_corporation_list {
    my ( $self, $full_reload ) = @_;

    my $eapi = Games::EveOnline::API->new();

    my $where = '';
    unless ( $full_reload ) {
        $where = " AND eh.corporation_id NOT IN (SELECT corporation_id FROM corporation_list) ";
    }

    my $corp_ids = $self->{db}->selectcol_arrayref("SELECT eh.corporation_id
            FROM employment_history eh
            WHERE 
            eh.corporation_id NOT IN (
                SELECT corporationID
                FROM evedeliveries.crpNPCCorporations
                GROUP BY corporationID ) 
            $where
            GROUP BY eh.corporation_id;", undef);

    return 1 if scalar @$corp_ids == 0;

    foreach my $id ( @$corp_ids ) {
        my $corp_info = $eapi->corporation_sheet( corporation_id => $id );
        $self->{api}->add_api_log('corporation_sheet', $corp_info );

        $self->{db}->do("INSERT INTO corporation_list (corporation_id, corporation_name, `ticker`, ceo_id, ceo_name, alliance_id, faction_id, description, member_count, `shares`, station_id, station_name, `url`, tax_rate, `logo`, cached_until) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef,
            $corp_info->{corporation_id},
            $corp_info->{corporation_name},
            $corp_info->{ticker},
            $corp_info->{ceo_id},
            $corp_info->{ceo_name},
            $corp_info->{alliance_id},
            $corp_info->{faction_id} || 0,
            ref $corp_info->{description} ne 'HASH' ? $corp_info->{description} : '',
            $corp_info->{member_count} || 0,
            $corp_info->{shares},
            $corp_info->{station_id} || 0,
            ref $corp_info->{station_name} ne 'HASH' ? $corp_info->{station_name} : '',
            ref $corp_info->{url} ne 'HASH' ? $corp_info->{url} : '',
            $corp_info->{tax_rate},
            encode_json( $corp_info->{logo} ),
            $corp_info->{cached_until} );
    }

    return 1;
}

sub update_corp_name {
    my ( $self ) = @_;

    my $eapi = Games::EveOnline::API->new();

    my $ids = $self->{db}->selectcol_arrayref("SELECT eh.corporation_id
            FROM employment_history eh
            WHERE eh.corporation_id NOT IN (
                SELECT character_id
                FROM character_names
                )
            GROUP BY corporation_id LIMIT 100", undef);
    
    return 1 if scalar @$ids == 0;

    my $names = $eapi->character_name( ids => join(',', @$ids) );
    $self->{api}->add_api_log('character_name', $names );
    my @values;
    foreach my $corp_id ( keys %$names ) {
        next unless $corp_id =~ /\d+/;

        $self->{db}->do("INSERT INTO character_names (character_id, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = name", undef, $corp_id, $names->{$corp_id} );
    }

    $self->update_corp_name();
}

sub update_eve_prices {
    my ( $self ) = @_; 

    my $user = 'Chips%20Merkaba';
    my $uri = URI->new( 'https://esi.tech.ccp.is/latest/markets/prices/?datasource=tranquility&user_agent=' . $user );

    my $ua = LWP::UserAgent->new;
    $ua->default_header('Accept' => 'application/json');
    $ua->default_header('X-User-Agent' => 'kaachips@gmail.com');
    my $response = $ua->get( $uri->as_string() );

    if ($response->is_success) {
        my $prices = decode_json($response->content);

        my $replaces = [];
        foreach my $price (@$prices) {
            push @$replaces, '('.$price->{type_id}.','. ( $price->{average_price} || 0 ).','.( $price->{adjusted_price} || 0 ).', NOW())';
        }

        my $sql = "REPLACE INTO eve_prices (type_id, average, adjusted, `date`) VALUES " . join(',', @$replaces);
        $self->{db}->do($sql);
    }
}


sub update_prices {
    my ( $self ) = @_; 

    my $type_ids = $self->{db}->selectcol_arrayref("
        ( SELECT ca.type_id 
        FROM character_assets ca 
        LEFT JOIN eve_central_prices ecp ON ecp.type_id = ca.type_id 
        WHERE ecp.type_id IS NULL GROUP BY ca.type_id )
        UNION
        (
            SELECT cci.type_id 
            FROM character_contract_items cci 
            LEFT JOIN eve_central_prices ecp ON ecp.type_id = cci.type_id 
            WHERE ecp.type_id IS NULL GROUP BY cci.type_id
        )
        LIMIT 50;
        ",undef);

    return unless scalar @$type_ids;

    my $ec = Games::EveOnline::EveCentral->new();
    my $prices = $ec->marketstat(
      Games::EveOnline::EveCentral::Request::MarketStat->new(
        type_id => $type_ids, # or [34, 35]. Mandatory.
        hours => 24, # defaults to 24
        min_q => 1, # defaults to 1
        system => 30000142, # Jita
        regions => 10000002, # or [10000002, 10000003],
      )->request
    );

    if (  $prices && scalar @$prices == 0 ) {
        print "NO DATA";
        return;
    }

    foreach my $p ( @$prices ) {
        foreach my $t ( qw/ all sell buy / ) {
            $self->{db}->do("
                INSERT INTO eve_central_prices (type_id, `type`, station_id, stddev, `volume`, `percentile`, `average`, `min`, `max`, `median`, `date`) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW() )
                ",undef,
                $p->{type_id},  $t, 30000142, $p->{$t}->{stddev},$p->{$t}->{volume},$p->{$t}->{percentile}, $p->{$t}->{average}, $p->{$t}->{min}, $p->{$t}->{max}, $p->{$t}->{median} );
        }
    }

    $ec       = undef;
    $type_ids = undef;
    $prices   = undef;

    $self->update_prices();
}

sub update_corp_contacts {
    my ( $self, %params ) = @_;     

    croak("No corp id specified") unless $params{corp_id};

    my $corp_id = $params{corp_id};
    my $ally_id = $params{ally_id} || 0;
    my ($key_id, $vcode);

    my $conf = YAML::Tiny->read( '/www/api_checker/config/corp_ally.yaml' )->[0];

    if ( defined $conf->{corps}->{$corp_id} ) {
        $key_id = $conf->{corps}->{$corp_id}->{key_id};
        $vcode  = $conf->{corps}->{$corp_id}->{vcode};
    }

    croak("No key_id or vcode found in config; Check corp_ally.yaml ") unless $key_id && $vcode;
    

    my $eapi = Games::EveOnline::API->new( user_id => $key_id, api_key => $vcode );

    my $contacts = $eapi->contact_list( type => 'corp' );

    if ( defined $contacts->{corporate_contact_list} && ref $contacts->{corporate_contact_list} eq 'HASH' ) {
        $self->{db}->do("DELETE FROM corp_contacts WHERE corp_or_ally_id = ?", undef, $corp_id);

        foreach my $c_id ( keys %{ $contacts->{corporate_contact_list} } ) {
            $self->{db}->do("INSERT INTO corp_contacts (corp_or_ally_id, contact_id, contact_name, contact_type_id, standing, cached_until) 
                VALUES (?, ?, ?, ?, ?, ?)", undef, $corp_id, $c_id, 
                $contacts->{corporate_contact_list}->{$c_id}->{contact_name},
                $contacts->{corporate_contact_list}->{$c_id}->{contact_type_id},
                $contacts->{corporate_contact_list}->{$c_id}->{standing},
                $contacts->{cached_until} || epoch2mydate(time(), 1 ),
            );
        }
    }

    if ( $ally_id && defined $contacts->{alliance_contact_list} && ref $contacts->{alliance_contact_list} eq 'HASH' ) {
        $self->{db}->do("DELETE FROM corp_contacts WHERE corp_or_ally_id = ?", undef, $ally_id);

        foreach my $c_id ( keys %{ $contacts->{alliance_contact_list} } ) {
            $self->{db}->do("INSERT INTO corp_contacts (corp_or_ally_id, contact_id, contact_name, contact_type_id, standing, cached_until) 
                VALUES (?, ?, ?, ?, ?, ?)", undef, $ally_id, $c_id, 
                $contacts->{alliance_contact_list}->{$c_id}->{contact_name},
                $contacts->{alliance_contact_list}->{$c_id}->{contact_type_id},
                $contacts->{alliance_contact_list}->{$c_id}->{standing},
                $contacts->{cached_until} || epoch2mydate(time(), 1 ),
            );
        }
    }

}

sub station_list {
    my ( $self ) = @_;

    my $eapi = Games::EveOnline::API->new();
    my $s = $eapi->station_list();

    # say scalar keys %$s;
    # return;

    $self->{db}->do("TRUNCATE station_list;",undef);
    foreach my $id ( keys %$s ) {
        next unless $id =~ /\d+/;

        my $res = $self->{db}->do("INSERT INTO station_list (station_id, station_name,station_type_id,solar_system_id,corporation_id,corporation_name,cached_until) 
            VALUES ( ?, ?, ?, ?, ?, ?, ?) ", undef, $id, $s->{$id}->{station_name}, $s->{$id}->{station_type_id}, $s->{$id}->{solar_system_id}, $s->{$id}->{corporation_id}, $s->{$id}->{corporation_name}, $s->{cached_until});

    }
}

sub get_all_corp_names {
    my ( $self ) = @_;

    my $corps = $self->{db}->selectall_arrayref( "
        SELECT corporation_id, corporation_name
        FROM apichecker.api_key_info aki
        GROUP BY corporation_id ORDER BY corporation_name", { Slice => {} } );

    return $corps;
}


1;