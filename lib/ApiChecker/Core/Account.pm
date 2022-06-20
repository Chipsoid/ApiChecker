package ApiChecker::Core::Account;

use utf8;
use POSIX;
use Modern::Perl;
use Data::Dumper;
use List::MoreUtils qw/ uniq /;

use ApiChecker::Core::Api;
use ApiChecker::Core::Utils qw(time_diff epoch2mydate subtract_set);

use lib '/www/Games-EveOnline-API/lib';
use Games::EveOnline::API;

sub new {
    my $class = shift;
    my $db    = shift;
    my $api   = shift;
    my $owner = shift || undef;
    
    $class = ref ($class) || $class;

    my $self;
    $self = {
        db      => $db,
        api     => $api,
        owner   => $owner,
    };

    bless $self, $class;
    return $self;
}

sub is_my_char {
    my ( $self, $char_id) = @_;

    my $answer = $self->{db}->selectrow_array("SELECT aki.character_id FROM api_key_info aki LEFT JOIN api a ON a.key = aki.key_id WHERE aki.character_id = ? AND a.user_id = ?", undef, $char_id, $self->{owner} );

    return $answer if $answer;

    $answer = $self->{db}->selectrow_array("SELECT aki.character_id FROM api_key_info aki LEFT JOIN user_corps a ON a.corporation_id = aki.corporation_id WHERE aki.character_id = ? AND a.user_id = ?", undef, $char_id, $self->{owner} );

    return $answer;

}

sub get_counts {
    my ( $self, $char_id ) = @_;

    my $result = {
        wallet_journal      => 0,
        wallet_transactions => 0,
        assets      => 0,
        contacts    => 0,
        contracts   => 0,
        mails       => 0,
    };

   

    foreach my $key ( keys %$result ) {
        my $where = '';
        if ( $key eq 'contacts' ) {
            $where .= ' AND archived_date IS NULL';
        }

        my $query = "SELECT COUNT(*) FROM character_". $key ." WHERE character_id = ? $where";
        $result->{$key} = $self->{db}->selectrow_array($query, undef, $char_id );
    }

    return $result;
}

sub get_supers {
    my ( $self, $accounts ) = @_;

    foreach my $acc ( @$accounts ) {
        $acc->{supers} = $self->{db}->selectall_arrayref(
            "SELECT ca.*, inTy.typeName as type_name, itN.itemName as location_name, sl.station_name as station_name
            FROM character_assets ca 
            LEFT JOIN `evedeliveries`.`invTypes` inTy ON inTy.typeID = ca.type_id
            LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID   = ca.location_id
            LEFT JOIN station_list sl ON sl.station_id = ca.location_id
            WHERE type_id IN (SELECT typeID FROM eve.invTypes WHERE groupID IN (30,659) ) AND ca.character_id = ?", { Slice => {} }, $acc->{character_id} );
    }
    
    return $accounts;
}

sub list {
    my ($self, $page, $per_page, $by, $order, $search, $user_id, $favorites, $is_bigboy ) = @_;

    my $order_by = "ORDER BY a.added DESC";
    if ( $by ~~ ['key_id','character_id', 'character_name', 'corporation_name', 'alliance_name'] ) {
        $order_by = "ORDER BY aki.$by $order";
    }

    my $where = ' WHERE deleted = 0 ';
    my $join  = ' ';
    if ( ref $search eq 'ARRAY' ) {
        foreach my $rule ( @$search ) {
            $where .=  'AND aki.' . $rule->{field} . " LIKE '%" . $rule->{value} . "%' ";
        }
    }
    if ( $favorites ) {
        $join  .= " LEFT JOIN favorites fav ON fav.character_id = aki.character_id ";
        $where .= " AND fav.user_id = $favorites ";
    }
    if ( $is_bigboy ) {
        my $char_with_supers = $self->{db}->selectcol_arrayref("SELECT character_id FROM character_assets ca WHERE type_id IN (SELECT typeID FROM eve.invTypes WHERE groupID IN (30,659) ) GROUP BY character_id", undef);
        $where .= " AND ( cs.is_bigboy = 1 OR aki.character_id IN (". join(',', @$char_with_supers) .") )";
    }

    if ( $self->{owner} ) {
        $where .= " AND ( a.user_id = " . $self->{owner} . " OR aki.corporation_id IN ( SELECT corporation_id FROM user_corps uc WHERE uc.user_id = ". $self->{owner} ." ) ) ";
    }

    my $sql = "SELECT COUNT(aki.key_id) FROM api_key_info aki INNER JOIN account_status acs ON acs.key_id = aki.key_id INNER JOIN api a ON a.key = aki.key_id INNER JOIN character_sheet cs ON cs.character_id = aki.character_id $join $where";

    # say $sql;
    my $count = $self->{db}->selectrow_array($sql, undef);

    if ( $count <= $per_page ) {
        return $self->{db}->selectall_arrayref("SELECT aki.*, acs.*, a.*, cs.*, ci.*, IF( npc.corporationID = aki.corporation_id, 1, 0 ) as is_npc, cl.ticker,
            ( SELECT 1 FROM favorites WHERE user_id = ? AND character_id = aki.character_id ) as is_favorite, t.tag_id
            FROM api_key_info aki 
            INNER JOIN account_status acs ON acs.key_id = aki.key_id 
            INNER JOIN api a ON a.key = aki.key_id AND a.status = 1
            INNER JOIN character_sheet cs ON cs.character_id = aki.character_id
            INNER JOIN character_info ci ON ci.character_id = aki.character_id
            LEFT JOIN evedeliveries.crpNPCCorporations npc ON npc.corporationID = aki.corporation_id
            LEFT JOIN corporation_list cl ON cl.corporation_id = aki.corporation_id
            LEFT JOIN tags t ON t.character_id = aki.character_id AND t.user_id = ?
            $join $where $order_by;", { Slice => {} }, $user_id, $user_id ) || [];
    }
    else {
        my $limit = " LIMIT ". ( $page * $per_page ) .", $per_page;";

        my $keys = $self->{db}->selectcol_arrayref(" SELECT aki.key_id FROM api_key_info aki INNER JOIN account_status acs ON acs.key_id = aki.key_id INNER JOIN api a ON a.key = aki.key_id  $join $where GROUP BY aki.key_id $order_by $limit", undef );

        if ( scalar @$keys > 0 ) { 
            return $self->{db}->selectall_arrayref("SELECT aki.*, acs.*, a.*, cs.*, ci.*, IF( npc.corporationID = aki.corporation_id, 1, 0 ) as is_npc, cl.ticker,
                ( SELECT 1 FROM favorites WHERE user_id = ? AND character_id = aki.character_id LIMIT 1 ) as is_favorite, t.tag_id
                FROM api_key_info aki 
                INNER JOIN account_status acs ON acs.key_id = aki.key_id 
                INNER JOIN api a ON a.key = aki.key_id  AND a.status = 1
                INNER JOIN character_sheet cs ON cs.character_id = aki.character_id
                INNER JOIN character_info ci ON ci.character_id = aki.character_id
                LEFT JOIN evedeliveries.crpNPCCorporations npc ON npc.corporationID = aki.corporation_id
                LEFT JOIN corporation_list cl ON cl.corporation_id = aki.corporation_id
                LEFT JOIN tags t ON t.character_id = aki.character_id AND t.user_id = ?
                $join $where AND aki.key_id IN (". join(',', @$keys) .") $order_by", { Slice => {} }, $user_id, $user_id ); 
        }            
    }

    return [];
}

sub get_accounts_page_count {
    my ( $self, $page, $per_page, $search, $favorites, $is_bigboy ) = @_;

    my $where = 'WHERE  deleted = 0  ';
    my $join  = '';
    if ( defined $search && ref $search eq 'ARRAY' ) {
        
        foreach my $rule ( @$search ) {
            $where .=  'AND aki.' . $rule->{field} . " LIKE '%" . $rule->{value} . "%' ";
        }
    }
    if ( $favorites ) {
        $join .= ' LEFT JOIN favorites fav ON fav.character_id = aki.character_id ';
        $where .= " AND fav.user_id = $favorites";
    }

    if ( $is_bigboy ) {
        $join .= ' JOIN character_sheet cs ON cs.character_id = aki.character_id ';
        $where .= " AND cs.is_bigboy = 1";
    }

    if ( $self->{owner} ) {
        $where .= " AND ( api.user_id = " . $self->{owner} . " OR aki.corporation_id IN ( SELECT corporation_id FROM user_corps uc WHERE uc.user_id = ". $self->{owner} ." ) ) ";
    }

    my $query = "SELECT COUNT(aki.key_id) FROM api_key_info aki  
    INNER JOIN account_status acs ON acs.key_id = aki.key_id 
    INNER JOIN character_info ci ON ci.character_id = aki.character_id 
    INNER JOIN api ON api.key = aki.key_id 
    $join 
    $where 
    GROUP BY aki.key_id";

    my $records_count = $self->{db}->selectall_arrayref($query, undef);
    return ceil( scalar @$records_count / $per_page ); 
}

sub get_char_id_by_name {
    my ( $self, $name ) = @_;
    return unless $name;

    return $self->{db}->selectrow_array("SELECT character_id FROM api_key_info WHERE character_name = ?", undef, $name);
}

sub get_mails {
    my ( $self, $char_id, $page, $per_page, $by, $order ) = @_;

    return {} unless $char_id;

    my $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";

    my $order_by = "ORDER BY cm.sent_date DESC";
    if ( $by ~~ ['sent_date','sender_name', 'to_name', 'title'] ) {
        $order_by = "ORDER BY $by $order";
    }

    my $mails = $self->{db}->selectall_arrayref( "SELECT cm.*, cn.name as to_name, cml.mail_list_name as mail_list_name FROM character_mails cm 
        LEFT JOIN character_names cn ON cn.character_id IN ( cm.to_character_ids ) OR cn.character_id IN ( cm.to_corp_or_alliance_id )
        LEFT JOIN character_mail_lists cml ON cml.mail_list_id = cm.to_list_id
        WHERE cm.character_id = ? GROUP BY cm.message_id $order_by $offset", { Slice => {} }, $char_id );

    foreach my $mail ( @$mails ) {
        $mail->{body_formatted} = _format_mail( $mail->{body} );
    }

    return $mails;
}

sub _format_mail {
    my ( $text ) = @_;

    my $fmt = $text;

    $fmt =~ s/<font size="\d+" color="#(\w+|\d+|\d+\w+|\w+\d+)">//ig;
    $fmt =~ s/<font\s+color="#(\w+|\d+|\d+\w+|\w+\d+)">//ig;
    $fmt =~ s/<font\s+color="#(\w+|\d+|\d+\w+|\w+\d+)" size="\d+">//ig;
    $fmt =~ s/<font\s+size="\d+">//ig;
    $fmt =~ s/<\/font>//ig;

    return $fmt;
}

sub get_mails_page_count {
    my ( $self, $char_id, $per_page ) = @_;

    return 0 unless $char_id;

    my $records_count = $self->{db}->selectrow_array("SELECT COUNT(id) FROM character_mails WHERE character_id = ?", undef, $char_id);

    return ceil( $records_count / $per_page );

}

sub _check_cached {
    my ( $self, $char_id, $table, $fld, $where_fld, $where_value ) = @_;

    $fld         ||= 'character_id';
    $where_fld   ||= 'character_id';
    $where_value ||= $char_id;

    my ($key_id, $cached_until) = $self->{db}->selectrow_array("SELECT $fld, DATE_ADD(cached_until, INTERVAL 3 HOUR ) FROM $table WHERE $where_fld = ? LIMIT 1", undef, $where_value);
    my $cached = defined $cached_until && time_diff( $cached_until, epoch2mydate(time(), 1 ) )->seconds() < 0  ? 1 : 0;

    return ( $key_id, $cached );
}

sub get_message_ids {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    return $self->{db}->selectcol_arrayref("SELECT message_id FROM character_mails WHERE character_id = ?", undef, $char_id );
}

sub set_mails {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_mails' );
    #return if $cached;

    my $mails;

    $mails = $self->_get_mails( $char_id );

    my $count = 0;

    if ( scalar keys %$mails > 0 && ! $key_id ) {
        my @values;
        foreach my $mes_id ( keys %$mails ) {
            next unless $mes_id =~ /\d+/;
                $count++;
                $self->{db}->do("INSERT INTO character_mails
                (character_id, message_id, to_character_ids, sender_id, sender_name, sent_date, to_corp_or_alliance_id, `title`, `body`, to_list_id, `cached_until`) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef, $char_id, 
                    $mes_id, 
                    $mails->{$mes_id}->{to_character_ids} || '', 
                    $mails->{$mes_id}->{sender_id}, 
                    $mails->{$mes_id}->{sender_name} || '', 
                    $mails->{$mes_id}->{sent_date},
                    $mails->{$mes_id}->{to_corp_or_alliance_id} || '',
                    $mails->{$mes_id}->{title} || '',
                    $mails->{$mes_id}->{body} || '',
                    $mails->{$mes_id}->{to_list_id} || '',
                    $mails->{cached_until} || epoch2mydate(time(), 1) );
        }
    }
    elsif ($key_id && scalar keys %$mails > 0 ) {
        my @values;
        foreach my $mes_id ( keys %$mails ) {
            next unless $mes_id =~ /\d+/;
            next if $self->{db}->selectrow_array("SELECT id FROM character_mails WHERE message_id = ? AND character_id = ?", undef, $mes_id, $char_id );
            $count++;
            $self->{db}->do("INSERT INTO character_mails
                (character_id, message_id, to_character_ids, sender_id, sender_name, sent_date, to_corp_or_alliance_id, `title`, `body`, to_list_id, `cached_until`) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef, $char_id, 
                    $mes_id, 
                    $mails->{$mes_id}->{to_character_ids} || '', 
                    $mails->{$mes_id}->{sender_id}, 
                    $mails->{$mes_id}->{sender_name} || '', 
                    $mails->{$mes_id}->{sent_date},
                    $mails->{$mes_id}->{to_corp_or_alliance_id} || '',
                    $mails->{$mes_id}->{title} || '',
                    $mails->{$mes_id}->{body} || '',
                    $mails->{$mes_id}->{to_list_id} || '',
                    $mails->{cached_until} || epoch2mydate( time(), 1) );
        }
    }

    $self->{db}->do(" UPDATE character_mails SET cached_until = ? WHERE character_id = ?", undef, $mails->{cached_until}, $char_id );

    return $count;

}

sub set_mail_lists {
    my ( $self, $char_id ) = @_;

    return 1 unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_mail_lists' );
    #return 1 if $cached;

    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $lists;
    $lists = $eapi->mail_lists( character_id => $char_id );
    $self->{api}->add_api_log('mail_lists', $lists, $key, $char_id );

    return 1 if defined $lists->{error} || ! $lists;

    if ( scalar keys %$lists && ! $key_id ) {

        my @values;
        foreach my $list_id ( keys %$lists ) {
            next unless $list_id =~ /\d+/;
            $self->{db}->do("INSERT INTO character_mail_lists
                (mail_list_id, character_id, mail_list_name, cached_until) 
                VALUES (?,?,?,?);", undef, $list_id, $char_id, $lists->{$list_id}, $lists->{cached_until});
        }
    }
    elsif ($key_id && scalar keys %$lists ) {

        my @values;
        foreach my $list_id ( keys %$lists ) {
            next unless $list_id =~ /\d+/;
            next if $self->{db}->selectrow_array("SELECT mail_list_id FROM character_mail_lists WHERE mail_list_id = ? AND character_id = ? LIMIT 1", undef, $list_id, $char_id );
            if ( scalar @values > 0 ) {
            $self->{db}->do("INSERT INTO character_mail_lists
                (mail_list_id, character_id, mail_list_name, cached_until) 
                VALUES (?,?,?,?);", undef, $list_id, $char_id, $lists->{$list_id}, $lists->{cached_until});
        }
        
        }
    }

    return 1;
}

sub get_mail_lists {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $lists = $self->{db}->selectall_arrayref( "SELECT * FROM character_mail_lists WHERE character_id = ?", { Slice => {} }, $char_id );

    return $lists;
}

sub _get_mails {
    my ( $self, $char_id ) = @_;

    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $messages = $eapi->mail_messages( character_id => $char_id );
    $self->{api}->add_api_log('mail_messages', $messages, $key,  $char_id );
    return {} if ! $messages || defined $messages->{error};

    my @mess_ids = ();

    foreach ( keys %$messages ) {
        next unless $_ =~ /\d+/;
        push @mess_ids, $_;
    }

    return $messages unless scalar @mess_ids;

    # my $new_ids = subtract_set( $have_mess_ids, \@mess_ids);

    # return $messages unless $new_ids;

    my $bodies = $eapi->mail_bodies( character_id => $char_id, ids => join( ',', @mess_ids ) );
    $self->{api}->add_api_log('mail_bodies', $bodies, $key, $char_id );
    my $full_messages;
    foreach my $mes_id ( keys %$bodies ) {
        next unless $mes_id  =~ /\d+/;
        $full_messages->{$mes_id} = $messages->{$mes_id};
        $full_messages->{$mes_id}->{body} = $bodies->{$mes_id};
    }

    return $full_messages;
}

sub get_character_attributes {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $attributes;

    $attributes = $self->{db}->selectall_arrayref("
        SELECT * FROM character_attributes WHERE character_id = ?
    ", { Slice => {} }, $char_id );

    return $attributes;
}

sub get_character_implants {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $implants;

    $implants = $self->{db}->selectall_arrayref("
        SELECT * FROM character_implants WHERE character_id = ?
    ", { Slice => {} }, $char_id );

    return $implants;
}

sub get_character_jump_clones {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $clones;

    $clones = $self->{db}->selectall_arrayref("
        SELECT * FROM character_jump_clones cjc
        LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = cjc.location_id 
        LEFT JOIN station_list sl ON sl.station_id = cjc.location_id
        WHERE character_id = ?
    ", { Slice => {} }, $char_id );

    return $clones;
}

sub set_character_contacts {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_contacts' );
    #return 1 if $cached;

    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $contacts;
    $contacts = $eapi->contact_list( character_id => $char_id );
    $self->{api}->add_api_log('contact_list', $contacts, $key, $char_id );

    my $npc = $self->{db}->selectcol_arrayref("SELECT agentID from evedeliveries.agtAgents;", undef);

    if ( $contacts->{contact_list} && ! $key_id ) {

        foreach my $contact_id ( keys %{$contacts->{contact_list}} ) {
            next if $contact_id ~~ @$npc;
            $self->{db}->do("INSERT INTO character_contacts
                (character_id, contact_id, contact_name, contact_type_id, standing, in_watchlist, cached_until, added_date) 
                VALUES (?, ?, ?, ?, ?, ?, ?, NOW() );", undef,
                    $char_id, $contact_id, $contacts->{contact_list}->{$contact_id}->{contact_name} || '',
                    $contacts->{contact_list}->{$contact_id}->{contact_type_id} || 0, 
                    $contacts->{contact_list}->{$contact_id}->{standing} || 0,
                    ( $contacts->{contact_list}->{$contact_id}->{in_watchlist} eq 'True' ? 1 : 0 ),
                    epoch2mydate( time() + 86400, 1 ) );
        }
    }
    elsif ( $key_id && $contacts->{contact_list} ) {

        my @ids_from_api;

        foreach my $contact_id ( keys %{$contacts->{contact_list}} ) {
            #  NPC  агентов пропускаем
            next if $contact_id ~~ @$npc;

            push @ids_from_api, $contact_id;

            my $in_watchlist = $contacts->{contact_list}->{$contact_id}->{in_watchlist} eq 'True' ? 1 : 0;

            my $exists = $self->{db}->selectrow_array("SELECT contact_id FROM character_contacts WHERE character_id = ? AND contact_id = ? AND standing = ? AND in_watchlist = ? AND archived_date IS NULL", undef, $char_id, $contact_id, $contacts->{contact_list}->{$contact_id}->{standing}, $in_watchlist );

            # Точно такой же контакт уже существует, пропускаем
            if ( $exists ) {
                $self->{db}->do("UPDATE character_contacts SET cached_until = ? WHERE character_id = ? AND contact_id = ? AND archived_date IS NULL", undef, epoch2mydate( time() + 86400, 1 ), $char_id, $contact_id);
                next;
            }

            my $updated = $self->{db}->selectall_arrayref("SELECT contact_id, contact_name, contact_type_id, standing, in_watchlist FROM character_contacts WHERE character_id = ? AND contact_id = ? AND archived_date IS NULL", { Slice => {} }, $char_id, $contact_id );
            if (
                scalar @$updated > 0 && (           
                    $updated->[0]->{contact_id}      != $contact_id ||
                    $updated->[0]->{contact_type_id} != $contacts->{contact_list}->{$contact_id}->{contact_type_id} ||
                    $updated->[0]->{contact_name}    ne $contacts->{contact_list}->{$contact_id}->{contact_name} ||
                    $updated->[0]->{in_watchlist}    != $in_watchlist
                )
            ) {
                # Какой-то из сущ. контактов обновился ( стенд или признак мониторинга )
                $self->{db}->do("UPDATE character_contacts
                SET contact_name = ?, contact_type_id = ?, standing = ?, in_watchlist = ?, cached_until = ? WHERE
                character_id = ? AND contact_id = ? AND archived_date IS NULL;", undef,
                    $contacts->{contact_list}->{$contact_id}->{contact_name} || '',
                    $contacts->{contact_list}->{$contact_id}->{contact_type_id} || 0, 
                    $contacts->{contact_list}->{$contact_id}->{standing} || 0,
                    $in_watchlist,
                    epoch2mydate( time() + 86400, 1 ), $char_id, $contact_id );
            }
            else {
                #  полностью новый контакт
                $self->{db}->do("INSERT INTO character_contacts
                    (character_id, contact_id, contact_name, contact_type_id, standing, in_watchlist, cached_until, added_date) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, NOW() );", undef,
                        $char_id, $contact_id, $contacts->{contact_list}->{$contact_id}->{contact_name} || '',
                        $contacts->{contact_list}->{$contact_id}->{contact_type_id} || 0, 
                        $contacts->{contact_list}->{$contact_id}->{standing} || 0,
                        $in_watchlist,
                        epoch2mydate( time() + 86400, 1 ) );
            }
        }

        my $ids_from_db = $self->{db}->selectcol_arrayref("SELECT contact_id FROM character_contacts WHERE character_id = ? AND archived_date IS NULL", undef, $char_id);

        # Архивируем контакты, которые удалены
        if ( scalar @$ids_from_db > 0 ) {
            foreach my $c_id ( @$ids_from_db ) {
                unless ( $c_id ~~ @ids_from_api ) {
                    $self->{db}->do("UPDATE character_contacts SET archived_date = NOW() WHERE character_id = ? AND contact_id = ? AND archived_date IS NULL", undef, $char_id, $c_id);
                }
            }
        }
    }

    return 1;
}

sub get_character_contacts {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $contacts = $self->{db}->selectall_arrayref( "SELECT cc.*, cl.ticker as ticker,ci.corporation_id, ci.alliance_id, 
        (SELECT cc1.standing FROM corp_contacts cc1 WHERE ( cc1.contact_id = cc.contact_id OR cc1.contact_id = ci.corporation_id OR cc1.contact_id = ci.alliance_id ) AND cc1.corp_or_ally_id = 928827408 LIMIT 1 ) as corp_standing,
        (SELECT cc2.standing FROM corp_contacts cc2 WHERE ( cc2.contact_id = cc.contact_id OR cc2.contact_id = ci.corporation_id OR cc2.contact_id = ci.alliance_id ) AND cc2.corp_or_ally_id = 1208295500 LIMIT 1 ) as ally_standing

        FROM character_contacts cc
        LEFT JOIN corporation_list cl ON cc.contact_id = cl.corporation_id
        LEFT JOIN character_info ci ON ci.character_id = cc.contact_id
        WHERE cc.character_id = ? AND cc.contact_id > 3019501 ORDER BY cc.standing DESC
", { Slice => {} }, $char_id );

    return $contacts;
}

sub get_character_skills {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $skills;

    $skills = $self->{db}->selectall_arrayref("
        SELECT cs.*, it.typeName, ig.groupName, ig.groupID
        FROM apichecker.character_skills cs 
        INNER JOIN evedeliveries.invTypes it ON it.typeID = cs.type_id 
        INNER JOIN evedeliveries.invGroups ig ON ig.groupID = it.groupID 
        WHERE cs.character_id = ? 
        ORDER BY ig.groupName, it.typeName ASC
    ", { Slice => {} }, $char_id );

    return $skills;
}

sub get_skillpoints {
    my ( $self, $char_id ) = @_;

    return [] unless $char_id;

    my $skill_points;

    $skill_points = $self->{db}->selectrow_array("
        SELECT SUM(cs.skill_points)
        FROM apichecker.character_skills cs 
        WHERE cs.character_id = ?
    ", { Slice => {} }, $char_id );

    return $skill_points;
}

sub set_wallet_transactions {
    my ( $self, $char_id ) = @_;

    return {} unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_wallet_transactions' );
    #return 1 if $cached;

    my $transes;
    $transes = $self->_get_wallet_transactions( $char_id );

    return 1 if defined $transes->{error} || ! $transes;

    $transes->{cached_until} ||= epoch2mydate(time()+3000, 1 );

    if ( scalar keys %$transes > 0 && ! $key_id ) {

        foreach my $trans_id ( keys %$transes ) {
            next unless $trans_id =~ /\d+/;

            $self->{db}->do("INSERT INTO character_wallet_transactions
            (`character_id`, `transaction_id`, `type_name`, `quantity`, `client_id`, `transaction_date_time`, `station_id`, `transaction_for`, `type_id`, `station_name`, `client_name`, `price`, `transaction_type`, `cached_until`) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef,
            $char_id, $trans_id,  $transes->{$trans_id}->{type_name} || '', $transes->{$trans_id}->{quantity} || '', $transes->{$trans_id}->{client_id} || '', $transes->{$trans_id}->{transaction_date_time}, $transes->{$trans_id}->{station_id}, $transes->{$trans_id}->{transaction_for}  || '', $transes->{$trans_id}->{type_id}    || '', $transes->{$trans_id}->{station_name}  || '', $transes->{$trans_id}->{client_name}  || '',  $transes->{$trans_id}->{price}    || 0, $transes->{$trans_id}->{transaction_type} || '', $transes->{cached_until}  );
        }
    }
    elsif ( $key_id && scalar keys %$transes > 0 ) {

        foreach my $trans_id ( keys %$transes ) {
            next unless $trans_id =~ /\d+/;
            next if $self->{db}->selectrow_array("SELECT id FROM character_wallet_transactions WHERE transaction_id = ? AND client_id = ? AND `transaction_date_time` = ? and character_id = ?", undef, $trans_id, $transes->{$trans_id}->{client_id}, $transes->{$trans_id}->{transaction_date_time},  $char_id );

             $self->{db}->do("INSERT INTO character_wallet_transactions
            (`character_id`, `transaction_id`, `type_name`, `quantity`, `client_id`, `transaction_date_time`, `station_id`, `transaction_for`, `type_id`, `station_name`, `client_name`, `price`, `transaction_type`, `cached_until`) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef,
            $char_id, $trans_id,  $transes->{$trans_id}->{type_name} || '', $transes->{$trans_id}->{quantity} || '', $transes->{$trans_id}->{client_id} || '', $transes->{$trans_id}->{transaction_date_time}, $transes->{$trans_id}->{station_id}, $transes->{$trans_id}->{transaction_for}  || '', $transes->{$trans_id}->{type_id}    || '', $transes->{$trans_id}->{station_name}  || '', $transes->{$trans_id}->{client_name}  || '',  $transes->{$trans_id}->{price}    || 0, $transes->{$trans_id}->{transaction_type} || '', $transes->{cached_until}  );
        }
    }

    $self->{db}->do(" UPDATE character_wallet_transactions SET cached_until = ? WHERE character_id = ?", undef, $transes->{cached_until}, $char_id );

    return 1;
}

sub get_wallet_transactions {
    my ( $self, $char_id, $page, $per_page, $by, $order ) = @_;

    return {} unless $char_id;

    my $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";
    $order ||= 'DESC';

    my $order_by = "ORDER BY wt.transaction_date_time DESC";
    if ( $by ~~ ['transaction_date_time','transaction_id', 'transaction_type', 'client_name', 'price', 'type_name', 'station_name'] ) {
        $order_by = "ORDER BY $by $order";
    }

    my $transes = $self->{db}->selectall_arrayref( "SELECT wt.* FROM apichecker.character_wallet_transactions wt WHERE wt.character_id = ? $order_by $offset", { Slice => {} }, $char_id );

    return $transes;
}

sub get_transactions_page_count {
    my ( $self, $char_id, $page, $per_page ) = @_;

    return 0 unless $char_id;

    my $records_count = $self->{db}->selectrow_array("SELECT COUNT(id) FROM character_wallet_transactions WHERE character_id = ?", undef, $char_id);

    return ceil( $records_count / $per_page );

}

sub _get_wallet_transactions {
    my ( $self, $char_id ) = @_;

    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $transes = $eapi->wallet_transactions( character_id => $char_id, from_id => '' );
    $self->{api}->add_api_log('wallet_transactions', $transes, $key,  $char_id );
    return $transes;
}

sub set_wallet_journal {
    my ( $self, $char_id ) = @_;

    return {} unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_wallet_journal', 'ref_id' );
    #return 1 if $cached;

    my $journal;
    $journal = $self->_get_wallet_journal( $char_id );

    return 1 if defined $journal->{error} || ! $journal;

    if ( scalar keys %$journal > 0 && ! $key_id ) {
        foreach my $ref_id ( keys %$journal ) {
            next unless $ref_id =~ /\d+/;

            $self->{db}->do("INSERT INTO character_wallet_journal
                (character_id, ref_id, `date`, reason, balance, ref_type_id, owner_id1, owner_name1, owner_id2, owner_name2, arg_id1, arg_name1, amount, tax_amount,   tax_receiver_id,  `cached_until`) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef,
                $char_id, $ref_id, $journal->{$ref_id}->{date}, $journal->{$ref_id}->{reason} || '', $journal->{$ref_id}->{balance}, $journal->{$ref_id}->{ref_type_id}, $journal->{$ref_id}->{owner_id1}, $journal->{$ref_id}->{owner_name1}, $journal->{$ref_id}->{owner_id2}, $journal->{$ref_id}->{owner_name2}, $journal->{$ref_id}->{arg_id1}, $journal->{$ref_id}->{arg_name1}, $journal->{$ref_id}->{amount}, $journal->{$ref_id}->{tax_amount} || '',  $journal->{$ref_id}->{tax_receiver_id} || '', $journal->{cached_until} );
        }
    }
    elsif ($key_id && scalar keys %$journal > 0 ) {
        foreach my $ref_id ( keys %$journal ) {
            next unless $ref_id =~ /\d+/;
            next if $self->{db}->selectrow_array("SELECT id FROM character_wallet_journal WHERE ref_id = ? AND ref_type_id = ? AND `date` = ? AND owner_id1 = ? AND arg_id1 = ? and character_id = ?", undef, $ref_id, $journal->{$ref_id}->{ref_type_id}, $journal->{$ref_id}->{date}, $journal->{$ref_id}->{owner_id1}, $journal->{$ref_id}->{arg_id1}, $char_id );

            $self->{db}->do("INSERT INTO character_wallet_journal
                (character_id, ref_id, `date`, reason, balance, ref_type_id, owner_id1, owner_name1, owner_id2, owner_name2, arg_id1, arg_name1, amount, tax_amount,   tax_receiver_id,  `cached_until`) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef,
                $char_id, $ref_id, $journal->{$ref_id}->{date}, $journal->{$ref_id}->{reason} || '', $journal->{$ref_id}->{balance}, $journal->{$ref_id}->{ref_type_id}, $journal->{$ref_id}->{owner_id1}, $journal->{$ref_id}->{owner_name1}, $journal->{$ref_id}->{owner_id2}, $journal->{$ref_id}->{owner_name2}, $journal->{$ref_id}->{arg_id1}, $journal->{$ref_id}->{arg_name1}, $journal->{$ref_id}->{amount}, $journal->{$ref_id}->{tax_amount} || '',  $journal->{$ref_id}->{tax_receiver_id} || '', $journal->{cached_until} );
        }
    }
    $self->{db}->do(" UPDATE character_wallet_journal SET cached_until = ? WHERE character_id = ?", undef, $journal->{cached_until}, $char_id );

    return 1;
}

sub get_wallet_journal {
    my ( $self, $char_id, $page, $per_page, $by, $order, $ref_type_id ) = @_;

    return {} unless $char_id;

    my $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";
    $order ||= 'DESC';

    my $order_by = "ORDER BY wj.date DESC";
    if ( $by ~~ ['date','ref_name', 'owner_name1', 'amount', 'balance'] ) {
        $order_by = "ORDER BY $by $order";
    }

    my $where = '';
    if ( $ref_type_id && $ref_type_id > 0 && $ref_type_id =~ /\d+/ ) {
        $where .= " AND ref_type_id = $ref_type_id";
    }

    my $journal = $self->{db}->selectall_arrayref( "
        SELECT wj.*, rt.ref_name, cwt.id as trans_id, cwt.client_name as client_name, cwt.quantity as quantity, cwt.type_name as type_name,
        cwt.station_name as station_name
        FROM character_wallet_journal wj 
        INNER JOIN ref_types rt ON rt.ref_id = wj.ref_type_id 
        LEFT JOIN character_wallet_transactions cwt ON cwt.character_id = wj.character_id AND cwt.price * cwt.quantity = ABS(wj.amount) AND cwt.transaction_date_time = wj.date
        WHERE wj.character_id = ? $where $order_by $offset", { Slice => {} }, $char_id );

    return $journal;
}

sub get_journal_ref_types {
    my ( $self, $char_id ) = @_;

    return {} unless $char_id;

    return $self->{db}->selectall_arrayref("SELECT wj.ref_type_id, rt.ref_name FROM character_wallet_journal wj INNER JOIN ref_types rt ON rt.ref_id = wj.ref_type_id WHERE wj.character_id = ? GROUP BY wj.ref_type_id", { Slice => {} }, $char_id );
}

sub get_journal_page_count {
    my ( $self, $char_id, $page, $per_page, $ref_type_id ) = @_;

    return 0 unless $char_id;

    my $where = '';

    if ( $ref_type_id && $ref_type_id > 0 && $ref_type_id =~ /\d+/ ) {
        $where .= " AND ref_type_id = $ref_type_id";
    }

    my $records_count = $self->{db}->selectrow_array("SELECT COUNT(ref_id) FROM character_wallet_journal WHERE character_id = ? $where", undef, $char_id);

    return ceil( $records_count / $per_page );

}

sub _get_wallet_journal {
    my ( $self, $char_id, $last_ref_id ) = @_;

    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $journal = $eapi->wallet_journal( character_id => $char_id, from_id => $last_ref_id || undef );
    $self->{api}->add_api_log('wallet_journal', $journal, $key,  $char_id );

    return $journal;
}

sub set_character_sheet {
    my ( $self, $char_id ) = @_;

    return {} unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_sheet' );
    #return 1 if $cached;

    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $character;
    $character = $eapi->character_sheet( character_id => $char_id );
    $self->{api}->add_api_log('character_sheet', $character, $key, $char_id );

    # say Dumper $character;

    return 1 if defined $character->{error}  || ! $character;

    if ( $character->{character_id} && ! $key_id ) {
        my @values = (
                $char_id,
                $character->{name},
                $character->{race},
                $character->{gender},
                $character->{blood_line},
                $character->{ancestry},
                $character->{date_of_birth},
                $character->{balance},
                $character->{cached_until},
                $character->{home_station_id},
                $character->{jump_activation},
                $character->{jump_fatigue},
                $character->{free_skill_points},
                $character->{clone_jump_date},
                $character->{free_respecs},
                $character->{remote_station_date},
                $character->{jump_last_update},
                $character->{last_respec_date},
                $character->{last_timed_respec},
            );
        $self->{db}->do("INSERT INTO character_sheet 
            (character_id, name, race, gender, blood_line, ancestry, date_of_birth, balance, cached_until,
            home_station_id, jump_activation, jump_fatigue, free_skill_points, clone_jump_date, free_respecs, remote_station_date, jump_last_update, last_respec_date, last_timed_respec) 
            VALUES 
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef, @values);

        $self->_update_character_info( $character );
    
    }
    elsif ( $key_id && $character->{character_id} ) {

        # say "all super";
        my @values = (
                $character->{name},
                $character->{race},
                $character->{gender},
                $character->{blood_line},
                $character->{ancestry},
                $character->{date_of_birth},
                $character->{balance},
                $character->{cached_until},
                $character->{home_station_id},
                $character->{jump_activation},
                $character->{jump_fatigue},
                $character->{free_skill_points},
                $character->{clone_jump_date},
                $character->{free_respecs},
                $character->{remote_station_date},
                $character->{jump_last_update},
                $character->{last_respec_date},
                $character->{last_timed_respec},
                $char_id,
            );
        $self->{db}->do("UPDATE character_sheet SET 
            name = ?, race = ?, gender = ?, blood_line = ?, ancestry = ?, date_of_birth = ?, balance = ?, cached_until = ?, home_station_id = ?, jump_activation = ?, jump_fatigue = ?, free_skill_points = ?, clone_jump_date = ?, free_respecs = ?, remote_station_date = ?, jump_last_update = ?, last_respec_date = ?, last_timed_respec = ?
            WHERE character_id = ?;", undef, @values);

        $self->_update_character_info( $character );

    }

    return 1;
}


sub get_character_sheet {
    my ( $self, $char_id ) = @_;

    return {} unless $char_id;

    my $character = $self->{db}->selectrow_hashref( "SELECT * FROM character_sheet cs
        LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = cs.home_station_id 
        LEFT JOIN station_list sl ON sl.station_id = cs.home_station_id
        WHERE character_id = ?", undef, $char_id );

    return $character;
}

sub set_corp_assets {
    my ( $self, $key, $vcode, $corp_id ) = @_;
    return {} unless $corp_id;

    my ($key_id, $cached) = $self->_check_cached( $corp_id, 'character_assets' );
    #return 1 if $cached;
    
    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $assets;
    $assets = $eapi->asset_list( type=>'corp' );
    $self->{api}->add_api_log('asset_list', $assets, $key, $corp_id );

    return 1 if defined $assets->{error} || ! $assets;

    if ( scalar keys %$assets > 0 ) {

        my $values = $self->_convert_assets_to_values($assets, $corp_id);

        if ( scalar @$values > 0 ) {
            $self->{db}->do("DELETE FROM character_assets WHERE character_id = ?", undef, $corp_id );

            my $sql = "INSERT INTO character_assets (character_id, type_id, item_id, location_id, quantity, flag, singleton, raw_quantity, contents, cached_until) VALUES " . join(',', @$values);

            $self->{db}->do($sql, undef);
        }

    }

    return 1;
}

sub set_character_assets {
    my ( $self, $char_id ) = @_;
    return {} unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_assets' );
    #return 1 if $cached;
    
    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $assets;
    $assets = $eapi->asset_list( character_id => $char_id );
    $self->{api}->add_api_log('asset_list', $assets, $key, $char_id );

    # say Dumper $assets;

    return 1 if defined $assets->{error} || ! $assets;

    if ( scalar keys %$assets > 0 ) {

        my $values = $self->_convert_assets_to_values($assets, $char_id);

        if ( scalar @$values > 0 ) {
            $self->{db}->do("DELETE FROM character_assets WHERE character_id = ?", undef, $char_id );

            $self->{db}->do("INSERT INTO character_assets (character_id, type_id, item_id, location_id, quantity, flag, singleton, raw_quantity, contents, cached_until) VALUES " . join(',', @$values), undef);
        }

    }

    return 1;
}

sub get_assets_sum {
    my ( $self, $char_id ) = @_;

    return 0 unless $char_id;

    my $sum = $self->{db}->selectrow_array("SELECT SUM(ep.average * ca.quantity) FROM character_assets ca LEFT JOIN eve_prices ep ON ep.type_id = ca.type_id WHERE ca.character_id = ? AND ca.raw_quantity <> -2;", undef, $char_id);

    return $sum;
}

sub get_assets_search {
    my ( $self, $char_id, $name ) = @_;
    return {} unless $char_id || $name;

    my $assets = {};

    my $type_ids = $self->{db}->selectcol_arrayref("SELECT typeID FROM evedeliveries.invTypes ity WHERE typeName LIKE '%$name%' ", undef);

    return {} if scalar @$type_ids == 0;

    $assets = $self->{db}->selectall_arrayref("SELECT ca.*, inTy.typeName as type_name, IF( ca.raw_quantity = -2, 1, 0 ) as is_bpc, IF( ca.raw_quantity <> -2, ep.average * ca.quantity, 0 ) as sell_price, itN.itemName as location_name, sl.station_name as station_name
            FROM apichecker.character_assets ca 
            LEFT JOIN `evedeliveries`.`invTypes` inTy ON inTy.typeID = ca.type_id
            LEFT JOIN eve_prices ep ON ca.type_id = ep.type_id 
            LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = ca.location_id 
            LEFT JOIN station_list sl ON sl.station_id = ca.location_id
            WHERE ca.character_id = ? AND ca.contents = 0 AND ca.type_id IN (". join(',', @$type_ids) .") ORDER BY type_name", {Slice=>{}}, $char_id);
    
    return $assets;
}

sub get_all_loc_names {
    my ( $self ) = @_;

    my $assets = $self->{db}->selectall_arrayref( "
        SELECT ca.location_id, itN.itemName as location_name, sl.station_name as station_name
        FROM apichecker.character_assets ca 
        LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = ca.location_id 
        LEFT JOIN station_list sl ON sl.station_id = ca.location_id
        WHERE ca.contents = 0 GROUP BY ca.location_id ORDER BY location_name", { Slice => {} } );

    return $assets;
}

sub get_assets_search_all {
    my ( $self, $name, $loc_id, $corp_id ) = @_;
    return {} unless $name;

    my $assets = {};

    my $type_ids = $self->{db}->selectcol_arrayref("SELECT typeID FROM evedeliveries.invTypes ity WHERE typeName LIKE '%$name%' ", undef);

    return {} if scalar @$type_ids == 0;

    my $where = '';
    if ( $loc_id ) {
        $where .= ' AND ca.location_id = '. $loc_id;
    }
    if ( $corp_id ) {
        $where .= ' AND aki.corporation_id = '. $corp_id;
    }

    $assets = $self->{db}->selectall_arrayref("SELECT ca.*, inTy.typeName as type_name, IF( ca.raw_quantity = -2, 1, 0 ) as is_bpc, IF( ca.raw_quantity <> -2, ep.average * ca.quantity, 0 ) as sell_price, itN.itemName as location_name, sl.station_name as station_name,
        cs.name as character_name,
        ( 
            SELECT SUM(ep2.average * ca2.quantity)
            FROM apichecker.character_assets ca2
            LEFT JOIN eve_prices ep2 ON ca2.type_id = ep2.type_id
            WHERE ca2.contents = ca.item_id AND ca2.raw_quantity <> -2
        ) + ( ep.average * ca.quantity ) as sum_content
            FROM apichecker.character_assets ca 
            LEFT JOIN `evedeliveries`.`invTypes` inTy ON inTy.typeID = ca.type_id
            LEFT JOIN eve_prices ep ON ca.type_id = ep.type_id 
            LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = ca.location_id 
            LEFT JOIN station_list sl ON sl.station_id = ca.location_id
            LEFT JOIN character_sheet cs ON cs.character_id = ca.character_id
            LEFT JOIN api_key_info aki ON aki.character_id = ca.character_id
            WHERE ca.contents = 0 AND ca.type_id IN (". join(',', @$type_ids) .") $where ORDER BY ca.character_id, type_name", { Slice=>{} } );
    
    return $assets;
}

sub get_character_assets {
    my ( $self, $char_id, $loc_id, $contents ) = @_;
    return {} unless $char_id || $loc_id;

    my $assets;


    my $items_ids = $self->{db}->selectcol_arrayref("
    SELECT ca.item_id FROM character_assets ca WHERE character_id = ? AND ( location_id = ? OR contents = ? ) GROUP BY ca.item_id
    " , undef, $char_id, $loc_id, $loc_id );
    $items_ids = [0] unless defined $items_ids->[0];

    my $containers = $self->{db}->selectcol_arrayref("
            SELECT ca.contents FROM character_assets ca WHERE character_id = ? AND contents IN (" . ( join(',', @$items_ids) ) . ")
            GROUP BY ca.contents;
        ", undef, $char_id);
    $containers = [0] unless defined $containers->[0];

    unless ( $contents ) {
        $assets = $self->{db}->selectall_arrayref( "
            SELECT ca.*, inTy.typeName as type_name, IF( ca.raw_quantity = -2, 1, 0 ) as is_bpc, 
                
                IF( ca.raw_quantity != -2, ep.average * ca.quantity, 0 ) as sell_price,
                
                IF( ca.item_id IN (" . join(',', @$containers) . "), 
                ( 
                    SELECT SUM(ep2.average * ca2.quantity)
                    FROM apichecker.character_assets ca2
                    LEFT JOIN eve_prices ep2 ON ca2.type_id = ep2.type_id
                    WHERE ca2.character_id = ca.character_id AND ca2.contents = ca.item_id AND ca2.raw_quantity != -2
                ) + ( ep.average * ca.quantity ), 0 ) as sum_content,
                
                IF((SELECT COUNT(ca3.item_id) FROM apichecker.character_assets ca3 WHERE ca3.contents = ca.item_id ), 
                1, 0 ) as have_content
            
            FROM apichecker.character_assets ca 
            LEFT JOIN `evedeliveries`.`invTypes` inTy ON inTy.typeID = ca.type_id
            LEFT JOIN eve_prices ep ON ca.type_id = ep.type_id
            WHERE ca.character_id = ? AND ca.location_id = ? AND ca.contents = 0 ORDER BY type_name", 
            { Slice => {} }, $char_id, $loc_id );
    }
    else {

        $assets = $self->{db}->selectall_arrayref( "
            SELECT ca.*, inTy.typeName as type_name, 

                IF( ca.raw_quantity <> -2, ep.average * ca.quantity, 0 ) as sell_price, 
                
                IF( ca.item_id IN (" . join(',', @$containers) . "), 
                        ( 
                            SELECT SUM(ep2.average * ca2.quantity)
                            FROM apichecker.character_assets ca2
                            LEFT JOIN eve_prices ep2 ON ca2.type_id = ep2.type_id
                            WHERE ca2.contents = ca.item_id AND ca2.raw_quantity != -2
                        ) + ( ep.average * ca.quantity ), 0 
                ) as sum_content,
                
                IF((SELECT COUNT(ca3.item_id) FROM apichecker.character_assets ca3 WHERE ca3.contents = ca.item_id ), 
                1, 0 ) as have_content
            
            FROM apichecker.character_assets ca 
            LEFT JOIN `evedeliveries`.`invTypes` inTy ON inTy.typeID = ca.type_id
            LEFT JOIN eve_prices ep ON ca.type_id = ep.type_id
            WHERE ca.character_id = ? AND ca.contents = ? ORDER BY type_name", 
            { Slice => {} }, $char_id, $loc_id );
    }

    return $assets;
}

sub get_character_assets_locations {
    my ( $self, $char_id ) = @_;
    return {} unless $char_id;

    my $assets = $self->{db}->selectall_arrayref( "
        SELECT ca.location_id, itN.itemName as location_name, sl.station_name as station_name, (
            SELECT SUM(ep2.average * ca2.quantity)
            FROM apichecker.character_assets ca2
            LEFT JOIN eve_prices ep2 ON ca2.type_id = ep2.type_id
            WHERE ca2.character_id = ca.character_id AND ca2.location_id = ca.location_id AND ca2.raw_quantity <> -2
        ) as sell_price
        FROM apichecker.character_assets ca 
        LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = ca.location_id 
        LEFT JOIN station_list sl ON sl.station_id = ca.location_id
        WHERE ca.character_id = ? AND ca.contents = 0 GROUP BY ca.location_id ORDER BY location_name", { Slice => {} }, $char_id );

    return $assets;
}

sub _convert_assets_to_values {
    my ( $self, $assets, $char_id, $parent_id, $parent_location_id ) = @_;

    $parent_id          ||= 0;
    $parent_location_id ||= 0;

    my $cached_until = epoch2mydate( time() + 86400, 1 );

    my @values;

    foreach my $item_id ( keys %$assets ) {
        my $a = $assets->{$item_id};


        push @values, '('. $char_id . ', ' . $a->{type_id} . ','. $a->{item_id} . ',' . ( $a->{location_id} || $parent_location_id ) . ',' . $a->{quantity} . ', '. $a->{flag} . ', '. $a->{singleton} . ', ' . ( $a->{raw_quantity} || 0 ) . ', ' . $parent_id . ', "' . $cached_until .'")';
        
        if ( defined $a->{contents} ) {

            push @values, @{ $self->_convert_assets_to_values( $a->{contents}, $char_id, $a->{item_id}, $a->{location_id} || 0 ) };
        }
    }

    return \@values;
}

sub set_account_status {
    my ($self, $key, $vcode) = @_;

    my ($key_id, $cached) = $self->_check_cached( 0, 'account_status', 'key_id', 'key_id', $key );
    #return 1 if $cached;

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $account;
    $account = $eapi->account_status();
    $self->{api}->add_api_log('account_status', $account, $key );
    if ( $account->{logon_count} && ! $key_id ) {
        my @values = (
                $key,
                $account->{paid_until},
                $account->{create_date},
                $account->{logon_count},
                $account->{logon_minutes},
                $account->{cached_until},
            );
        $self->{db}->do("INSERT INTO account_status 
            (key_id, paid_until, create_date, logon_count, logon_minutes, cached_until) 
            VALUES 
            (?, ?, ?, ?, ?, ?);", undef, @values);
    }
    elsif ( $key_id && $account->{logon_count} ) {
        my @values = (
                $account->{paid_until},
                $account->{logon_count},
                $account->{logon_minutes},
                $account->{cached_until},
                $key,
            );
        $self->{db}->do("UPDATE account_status SET 
            paid_until = ?, logon_count = ?, logon_minutes = ?, cached_until = ?
            WHERE key_id = ?;", undef, @values);
    }

    return 1;
}

sub get_account_status {
    my ($self, $key, $vcode) = @_;

    my $account = $self->{db}->selectall_arrayref( "SELECT * FROM account_status WHERE key_id = ?", { Slice => {} }, $key );

    return $account;
}

sub get_api_key_info {
    my ( $self, $key ) = @_;

    return() unless $key;

    return $self->{db}->selectall_arrayref( "SELECT * FROM api_key_info WHERE key_id = ?", { Slice => {}}, $key );
}

sub set_api_key_info {
    my ($self, $key, $vcode) = @_;

    my ($key_id, $cached) = $self->_check_cached( 0, 'api_key_info', 'key_id', 'key_id', $key );
    #return 'CACHED' if $cached;

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $info;
    $info = $eapi->api_key_info();

    $self->{api}->add_api_log('api_key_info', $info, $key );

    return 0 if defined $info->{error} || ! $info;

    if ( $info->{access_mask} && $info->{characters} && ! $key_id ) {
        foreach my $char_id ( keys %{ $info->{characters} } ) {
            
            # если рабочий ключ на чара уже существует, то этот помечаем  выключенным
            # но все равно записываем
            if ( $self->{api}->check_same_api( $char_id ) ) {
                $self->{api}->update_status( 0, $key );
            }

            my @values = (
                $key,
                $info->{access_mask},
                $info->{type},
                $info->{expires} || '0000-00-00 00:00:00',
                $char_id,
                $info->{characters}->{$char_id}->{character_name},
                $info->{characters}->{$char_id}->{corporation_id},
                $info->{characters}->{$char_id}->{corporation_name},
                $info->{characters}->{$char_id}->{alliance_id},
                $info->{characters}->{$char_id}->{alliance_name},
                $info->{characters}->{$char_id}->{faction_id} || 0,
                $info->{characters}->{$char_id}->{faction_name} || '',
                $info->{cached_until},
            );
            my $result = $self->{db}->do("INSERT INTO api_key_info 
                (key_id, access_mask, type, expires, character_id, character_name, corporation_id, corporation_name, alliance_id, alliance_name, faction_id, faction_name, cached_until) 
                VALUES 
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef, @values);
        }
    }
    elsif ( $key_id && $info->{access_mask} && $info->{characters}  ) {
        # TODO: Add logic for new chars on known account
        foreach my $char_id ( keys %{ $info->{characters} } ) {
            next if $self->{db}->selectrow_array("SELECT id FROM api_key_info WHERE character_id = ? and key_id = ? and DATE_ADD(cached_until, INTERVAL 3 HOUR ) >= NOW() ", undef, $char_id, $key );

            my $exist_char;
            $exist_char = 1 if $self->{db}->selectrow_array("SELECT id FROM api_key_info WHERE character_id = ? and key_id = ?", undef, $char_id, $key );
            # Чар уже существует на этом акке с этим ключом
            if ( $exist_char ) {
                my @values = (
                $info->{access_mask},
                $info->{type},
                $info->{expires},
                $char_id,
                $info->{characters}->{$char_id}->{character_name},
                $info->{characters}->{$char_id}->{corporation_id},
                $info->{characters}->{$char_id}->{corporation_name},
                $info->{characters}->{$char_id}->{alliance_id},
                $info->{characters}->{$char_id}->{alliance_name},
                $info->{characters}->{$char_id}->{faction_id},
                $info->{characters}->{$char_id}->{faction_name},
                $info->{cached_until},
                $key,
                $char_id,
                );
                $self->{db}->do("UPDATE api_key_info SET access_mask = ?, type = ?, expires = ?, character_id = ?, character_name = ?, corporation_id = ?, corporation_name = ?, alliance_id = ?, alliance_name = ?, faction_id = ?, faction_name = ?, cached_until = ? WHERE key_id = ? and character_id = ?;", undef, @values);
            }
            # Новый чар на аккаунте
            else {
                my @values = (
                $key,
                $info->{access_mask},
                $info->{type},
                $info->{expires} || '0000-00-00 00:00:00',
                $char_id,
                $info->{characters}->{$char_id}->{character_name},
                $info->{characters}->{$char_id}->{corporation_id},
                $info->{characters}->{$char_id}->{corporation_name},
                $info->{characters}->{$char_id}->{alliance_id},
                $info->{characters}->{$char_id}->{alliance_name},
                $info->{characters}->{$char_id}->{faction_id} || 0,
                $info->{characters}->{$char_id}->{faction_name} || '',
                $info->{cached_until},
                );
                $self->{db}->do("INSERT INTO api_key_info 
                    (key_id, access_mask, type, expires, character_id, character_name, corporation_id, corporation_name, alliance_id, alliance_name, faction_id, faction_name, cached_until) 
                    VALUES 
                    (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", undef, @values);
            }
            
        }
    }
    elsif ( defined $info->{error} ) {
        return 0;
    }

    return 1;
}

sub _update_character_info {
    my ($self, $character ) = @_;

    # Skills
    $self->{db}->do("DELETE FROM character_skills WHERE character_id = ?", undef, $character->{character_id} );
    my @skills;
    foreach my $type_id ( keys %{ $character->{skills} } ) {
        push @skills, "( ". $character->{character_id} .", $type_id,  ". $character->{skills}->{$type_id}->{skill_points} . ', '. $character->{skills}->{$type_id}->{level} .', "' . $character->{cached_until} . '" )';
    }

    $self->{db}->do("INSERT INTO character_skills (character_id, type_id, skill_points, level, cached_until) VALUES " . join(',', @skills), undef);

    # Attributes
    $self->{db}->do("DELETE FROM character_attributes WHERE character_id = ?", undef, $character->{character_id});
    $self->{db}->do("INSERT INTO character_attributes (character_id, memory, intelligence, charisma, willpower, perception, cached_until) 
        VALUES (?, ?, ?, ?, ?, ?, ?) ", undef, 
        $character->{character_id}, 
        $character->{attributes}->{memory},
        $character->{attributes}->{intelligence},
        $character->{attributes}->{charisma},
        $character->{attributes}->{willpower},
        $character->{attributes}->{perception},
        $character->{cached_until},
    );

    # implants
    $self->{db}->do("DELETE FROM character_implants WHERE character_id = ?", undef, $character->{character_id});
    if ( scalar keys %{ $character->{implants} } > 0 ) {
        foreach my $imp ( keys %{ $character->{implants} } ) {
            $self->{db}->do("INSERT INTO character_implants (character_id, type_id, name ) VALUES (?, ?, ?)", undef, 
                 $character->{character_id}, $imp, $character->{implants}->{$imp} );
        }
    }

    #jump clones
    $self->{db}->do("DELETE FROM character_jump_clones WHERE character_id = ?", undef, $character->{character_id});
    if ( scalar keys %{ $character->{jump_clones} } > 0 ) {
        foreach my $clone_id ( keys %{ $character->{jump_clones} } ) {
            $self->{db}->do("INSERT INTO character_jump_clones (id, character_id, type_id, name, location_id ) VALUES (?, ?, ?, ?, ?)", undef, 
                 $clone_id, $character->{character_id}, $character->{jump_clones}->{$clone_id}->{type_id}, $character->{jump_clones}->{$clone_id}->{clone_name}, $character->{jump_clones}->{$clone_id}->{location_id} );
        }
    }

}

sub set_contracts {
    my ( $self, $char_id ) = @_;
    return {} unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_contracts' );
    #return 1 if $cached;
    
    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $contracts;
    $contracts = $eapi->contracts( character_id => $char_id );
    $self->{api}->add_api_log('contracts', $contracts, $key, $char_id );

    return 1 if defined $contracts->{error} || ! $contracts;

    if ( scalar keys %$contracts > 0 ) {
        foreach my $c_id ( keys %$contracts ) {
            next unless $c_id =~ /\d+/;

            next if $self->{db}->selectrow_array("SELECT contract_id FROM character_contracts WHERE character_id = ? and contract_id = ?", undef, $char_id, $c_id );

            $self->{db}->do("INSERT INTO character_contracts 
                (`character_id`, `contract_id`, `issuer_id`, `issuer_corp_id`, `assignee_id`, `acceptor_id`, `start_station_id`, `end_station_id`, `type`, `status`, `title`, `for_corp`, `availability`, `date_issued`, `date_expired`, `date_accepted`, `num_days`, `date_completed`, `price`, `reward`, `collateral`, `buyout`, `volume`, `cached_until`) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", undef,
                $char_id, $c_id, $contracts->{$c_id}->{issuer_id} || 0, $contracts->{$c_id}->{issuer_corp_id} || 0, 
                $contracts->{$c_id}->{assignee_id} || 0, $contracts->{$c_id}->{acceptor_id} || 0,
                $contracts->{$c_id}->{start_station_id} || 0, $contracts->{$c_id}->{end_station_id} || 0, 
                $contracts->{$c_id}->{type}, $contracts->{$c_id}->{status},
                $contracts->{$c_id}->{title} || '', $contracts->{$c_id}->{for_corp} || 0,
                $contracts->{$c_id}->{availability}, $contracts->{$c_id}->{date_issued},
                $contracts->{$c_id}->{date_expired}, $contracts->{$c_id}->{date_accepted}, 
                $contracts->{$c_id}->{num_days}, $contracts->{$c_id}->{date_completed},
                $contracts->{$c_id}->{price}, $contracts->{$c_id}->{reward}, 
                $contracts->{$c_id}->{collateral}, $contracts->{$c_id}->{buyout}, 
                $contracts->{$c_id}->{volume}, $contracts->{cached_until}
            );
            
            $self->set_contract_items( $char_id, $c_id, $key, $eapi );

        }
    }

    return 1;
}

sub set_contract_items {
    my ( $self, $char_id, $contract_id, $key, $eapi ) = @_;
    return {} unless $char_id && $contract_id && $key && $eapi;

    my $items;
    $items = $eapi->contract_items( character_id => $char_id, contract_id => $contract_id );
    $self->{api}->add_api_log('contract_items', $items, $key, $char_id );

    return 1 if defined $items->{error} || ! $items;

    if ( scalar keys %$items > 0 ) {
        foreach my $record ( @{$items->{$contract_id}} ) {

            $self->{db}->do("INSERT INTO character_contract_items 
                ( character_id, contract_id, record_id, type_id, quantity, raw_quantity, singleton, included
                ) VALUES 
                (?, ?, ?, ?, ?, ?, ?, ?)", undef, $char_id, $contract_id, $record->{record_id}, $record->{type_id}, 
                $record->{quantity}, $record->{raw_quantity}, $record->{singleton}, $record->{included});
        }
    }

    return 1;
}

sub get_contracts {
    my ( $self, $char_id, $page, $per_page, $by, $order ) = @_;

    return {} unless $char_id;

    my $offset = $page ? " LIMIT ". ( $page * $per_page ) .", $per_page;":'';
    $order ||= 'DESC';

    my $order_by = "ORDER BY date_issued $order";
    # if ( $by ~~ ['transaction_date_time','transaction_id', 'transaction_type', 'client_name', 'price', 'type_name', 'station_name'] ) {
    #     $order_by = "ORDER BY $by $order";
    # }

    my $contracts = $self->{db}->selectall_arrayref("SELECT cc.*, 
            itN.itemName as start_location_name, sl.station_name as start_station_name,
            itN2.itemName as end_location_name, sl2.station_name as end_station_name,
            ( SELECT name FROM character_names WHERE character_id = cc.issuer_id ) as issuer_name,
            ( SELECT name FROM character_names WHERE character_id = cc.assignee_id ) as assignee_name,
            ( SELECT name FROM character_names WHERE character_id = cc.acceptor_id ) as acceptor_name,
            (
                SELECT COUNT(*) FROM character_contract_items cci WHERE cci.contract_id = cc.contract_id
            ) as items_count,
            IF( (
                SELECT COUNT(*) FROM character_contract_items cci WHERE cci.contract_id = cc.contract_id
            ) = 1, ( 
                SELECT inTy.typeName as type_name
                FROM character_contract_items cci2
                LEFT JOIN evedeliveries.invTypes inTy ON inTy.typeID = cci2.type_id
                WHERE cci2.contract_id = cc.contract_id
            ), '' ) as one_item_name
            FROM apichecker.character_contracts cc 
            LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = cc.start_station_id
            LEFT JOIN station_list sl ON sl.station_id = cc.start_station_id
            LEFT JOIN `evedeliveries`.`invNames` itN2 ON itN2.itemID = cc.start_station_id
            LEFT JOIN station_list sl2 ON sl2.station_id = cc.start_station_id
            WHERE cc.character_id = ? $order_by $offset", {Slice=>{}}, $char_id);

    return $contracts;
}

sub get_contract_items {
    my ( $self, $char_id, $contract_id ) = @_;

    my $contract = $self->{db}->selectall_arrayref("SELECT cc.*, 
            itN.itemName as start_location_name, sl.station_name as start_station_name,
            itN2.itemName as end_location_name, sl2.station_name as end_station_name,
            ( SELECT name FROM character_names WHERE character_id = cc.issuer_id ) as issuer_name,
            ( SELECT name FROM character_names WHERE character_id = cc.assignee_id ) as assignee_name,
            ( SELECT name FROM character_names WHERE character_id = cc.acceptor_id ) as acceptor_name
            FROM apichecker.character_contracts cc 
            LEFT JOIN `evedeliveries`.`invNames` itN ON itN.itemID = cc.start_station_id
            LEFT JOIN station_list sl ON sl.station_id = cc.start_station_id
            LEFT JOIN `evedeliveries`.`invNames` itN2 ON itN2.itemID = cc.start_station_id
            LEFT JOIN station_list sl2 ON sl2.station_id = cc.start_station_id
            WHERE cc.character_id = ? AND contract_id = ? ORDER BY date_issued", {Slice=>{}}, $char_id, $contract_id);

    my $items = $self->{db}->selectall_arrayref("
        SELECT cci.*, inTy.typeName as type_name,
        ep.average * cci.quantity as sell_price
        FROM character_contract_items cci
        LEFT JOIN evedeliveries.invTypes inTy ON inTy.typeID = cci.type_id
        LEFT JOIN eve_prices ep ON cci.type_id = ep.type_id
        WHERE cci.character_id = ? AND contract_id = ? GROUP BY record_id ORDER BY type_name
        ", { Slice=>{} }, $char_id, $contract_id);

    return [ $contract, $items ];
}

sub get_contracts_page_count {
    my ( $self, $char_id, $page, $per_page ) = @_;

    return 0 unless $char_id;

    my $where = '';

    my $records_count = $self->{db}->selectrow_array("SELECT COUNT(id) FROM character_contracts WHERE character_id = ? $where", undef, $char_id);

    return ceil( $records_count / $per_page );

}

sub set_character_skill_training {
    my ( $self, $char_id ) = @_;
    return {} unless $char_id;

    my ($key_id, $cached) = $self->_check_cached( $char_id, 'character_skill_training' );
    #return 1 if $cached;
    
    my ($key, $vcode) = $self->{api}->get_by_char_id( $char_id );

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $skill_train;
    $skill_train = $eapi->skill_in_training( character_id => $char_id );
    $self->{api}->add_api_log('skill_in_training', $skill_train, $key, $char_id );

    return 1 if defined $skill_train->{error} || ! $skill_train;

    return unless $skill_train->{start_time} && $skill_train->{to_level};

    if ( scalar keys %$skill_train > 0 ) {
            $self->{db}->do("INSERT INTO character_skill_training (character_id, start_time, end_time, skill_id, start_sp, end_sp, to_level, current_tq_time, offset, cached_until) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", undef,
                $char_id,
                $skill_train->{start_time},
                $skill_train->{end_time},
                $skill_train->{skill_id},
                $skill_train->{start_sp},
                $skill_train->{end_sp},
                $skill_train->{to_level},
                $skill_train->{current_tq_time}->{content},
                $skill_train->{current_tq_time}->{offset},
                $skill_train->{cached_until},
                );
    }

    return 1;
}

sub get_character_skill_training {
    my ( $self, $char_id ) = @_;
    return [] unless $char_id;

    return $self->{db}->selectall_arrayref("SELECT cst.*, eit.typeName as skill_name FROM character_skill_training cst 
            INNER JOIN evedeliveries.invTypes eit ON eit.typeID = cst.skill_id WHERE character_id = ? ORDER BY cst.id DESC LIMIT 1", { Slice => {} }, $char_id) || [];

}


1;
