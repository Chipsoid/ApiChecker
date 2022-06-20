package ApiChecker::Core::Corp;

use utf8;
use POSIX;
use Modern::Perl;
use Data::Dumper;
use List::MoreUtils qw/ uniq /;

use ApiChecker::Core::Api;
use ApiChecker::Core::Utils qw(time_diff epoch2mydate subtract_set);

use lib '../Games-EveOnline-API/lib';
use Games::EveOnline::API;


sub new {
    my $class = shift;
    my $db    = shift;
    my $api   = shift;
    
    $class = ref ($class) || $class;

    my $self;
    $self = {
        db      => $db,
        api     => $api,
    };

    bless $self, $class;
    return $self;
}


sub get_industry_jobs {
    my ($self, $where_params, $page, $per_page, $by, $order) = @_;

    my $offset = '';
    my $order_by = "ORDER BY ij.job_id DESC";

    if ( defined $page && $per_page ) {
        $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";
    }

    if ( $by && $by ~~ ['solar_system_id','corporation_id', 'installer_id', 'facility_id'] ) {
        $order_by = "ORDER BY ij.$by $order";
    }

    my $where = '1 = 1';
    my @bind = ();

    if ($where_params) {
        if ( defined $where_params->{corporation_id} ) {
            $where .= ' AND corporation_id = ?';
            push @bind, $where_params->{corporation_id};
        }
        if ( defined $where_params->{character_id} ) {
            $where .= ' AND corporation_id = 0 AND ( installer_id = ? OR completed_character_id = ?)';
            push @bind, $where_params->{character_id};
            push @bind, $where_params->{character_id};
        }
    }

    my $jobs = $self->{db}->selectall_arrayref("
        SELECT ij.*, s1.name as facility_name, s2.name as station_name
        FROM industry_jobs ij 
        LEFT JOIN structures s1 ON s1.structure_id = ij.facility_id
        LEFT JOIN structures s2 ON s2.structure_id = ij.station_id
        -- LEFT JOIN character_assets ca3 ON ca3.item_id = ij.blueprint_location_id
        -- LEFT JOIN character_assets ca4 ON ca4.item_id = ij.output_location_id
        -- LEFT JOIN `evedeliveries`.`invTypes` inTy1 ON inTy1.typeID = ca1.type_id
        -- LEFT JOIN `evedeliveries`.`invTypes` inTy2 ON inTy2.typeID = ca2.type_id
        -- LEFT JOIN `evedeliveries`.`invTypes` inTy3 ON inTy3.typeID = ca3.type_id
        -- LEFT JOIN `evedeliveries`.`invTypes` inTy4 ON inTy4.typeID = ca4.type_id
        WHERE $where $order_by $offset", { Slice => {} }, @bind ) || [];

    return $jobs;
}

sub get_corp_id_by_key {
    my ( $self, $key ) = @_;

    return unless $key;


    return $self->{db}->selectrow_array("SELECT corporation_id FROM api_key_info WHERE key_id = ?", undef, $key);
}

sub set_industry_jobs {
    my ( $self, $key, $vcode, $corp_id ) = @_;

    $corp_id ||= 0;

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $jobs;

    my %params;
    if ($corp_id) {
        $params{type} = 'corp';
    }
    $jobs = $eapi->industry_jobs(%params);

    return 1 if defined $jobs->{error} || ! $jobs;


    if ( scalar keys %$jobs > 0 ) {
        foreach my $job_id ( keys %$jobs ) {
            next if $job_id eq 'cached_until';

            $self->{db}->do("REPLACE INTO industry_jobs SET
                  `job_id` = ?,
                  `corporation_id` = ?,
                  `installer_id` = ?,
                  `installer_name` = ?,
                  `facility_id` = ?,
                  `solar_system_id` = ?,
                  `solar_system_name` = ?,
                  `station_id` = ?,
                  `activity_id` = ?,
                  `blueprint_id` = ?,
                  `blueprint_type_id` = ?,
                  `blueprint_type_name` = ?,
                  `blueprint_location_id` = ?,
                  `output_location_id` = ?,
                  `runs` = ?,
                  `cost` = ?,
                  `licensed_runs` = ?,
                  `probability` = ?,
                  `product_type_id` = ?,
                  `product_type_name` = ?,
                  `status` = ?,
                  `time_in_seconds` = ?,
                  `start_date` = ?,
                  `end_date` = ?,
                  `pause_date` = ?,
                  `completed_date` = ?,
                  `completed_character_id` = ?,
                  `successful_runs` = ?,
                  `cached_until` = ?
                ", undef, 
                $job_id,
                $corp_id,
                $jobs->{$job_id}->{installer_id} || 0,
                $jobs->{$job_id}->{installer_name},
                $jobs->{$job_id}->{facility_id} || 0,
                $jobs->{$job_id}->{solar_system_id} || 0,
                $jobs->{$job_id}->{solar_system_name} || '',
                $jobs->{$job_id}->{station_id} || 0,
                $jobs->{$job_id}->{activity_id} || 0,
                $jobs->{$job_id}->{blueprint_id} || 0,
                $jobs->{$job_id}->{blueprint_type_id} || 0,
                $jobs->{$job_id}->{blueprint_type_name},
                $jobs->{$job_id}->{blueprint_location_id} || '',
                $jobs->{$job_id}->{output_location_id} || 0,
                $jobs->{$job_id}->{runs} || 0,
                $jobs->{$job_id}->{cost} || 0,
                $jobs->{$job_id}->{licensed_runs} || 0,
                $jobs->{$job_id}->{probability} || 1,
                $jobs->{$job_id}->{product_type_id} || 0,
                $jobs->{$job_id}->{product_type_name},
                $jobs->{$job_id}->{status} || 0,
                $jobs->{$job_id}->{time_in_seconds} || 0,
                $jobs->{$job_id}->{start_date} || 0,
                $jobs->{$job_id}->{end_date} || 0,
                $jobs->{$job_id}->{pause_date} || 0,
                $jobs->{$job_id}->{completed_date} || 0,
                $jobs->{$job_id}->{completed_character_id} || 0,
                $jobs->{$job_id}->{successful_runs} || 0,
                $jobs->{cached_until}
            );

            if ( $self->{db}->err ) {
                die "ERROR! return code:" . $self->{db}->err . " error msg: " . $self->{db}->errstr . "\n";
            }
        }
    }
    return 1;
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

sub get_starbase_list {
    my ($self, $page, $per_page, $by, $order) = @_;

    my $offset = '';
    my $order_by = "ORDER BY csl.id DESC";

    if ( defined $page && $per_page ) {
        $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";
    }

    if ( $by && $by ~~ ['location_id','type_id', 'standing_owner_id', 'corp_key_id'] ) {
        $order_by = "ORDER BY csl.$by $order";
    }

    my $starbases = $self->{db}->selectall_arrayref("SELECT csl.*, 
        ( SELECT typeName FROM evedeliveries.invTypes WHERE typeID = csl.type_id ) as type_name,
        ( select constellationName from evedeliveries.mapConstellations where constellationID = 
                        (SELECT constellationID FROM evedeliveries.mapSolarSystems WHERE solarSystemID = csl.location_id )
                    ) as const_name,
        ( select regionName from evedeliveries.mapRegions where regionID = 
                        (SELECT regionID FROM evedeliveries.mapSolarSystems WHERE solarSystemID = csl.location_id )
                    ) as region_name,
        ( select solarSystemName from evedeliveries.mapSolarSystems where solarSystemID = csl.location_id ) as location_name,
        ( select itemName from evedeliveries.mapDenormalize where itemID = csl.moon_id) as moon_name,
        ( select name from character_names where character_id = csl.standing_owner_id  ) as owner_name,
        ( SELECT typeName FROM evedeliveries.invTypes WHERE typeID = ( 
            SELECT mat_type_id FROM eve_moon_mats
            WHERE moon_item_id = csl.moon_id
         ) ) as moon_mat,
        ( select corporation_name FROM api_key_info WHERE key_id = csl.corp_key_id) as corp_name
        FROM corp_starbase_list csl $order_by $offset", { Slice => {} } ) || [];

    foreach my $sb ( @$starbases ) {
        $sb->{detail} = $self->get_starbase_details( $sb->{item_id} );
    }

    return $starbases;
}

sub get_starbase_details {
    my ($self, $starbase_id) = @_;

    return {} unless $starbase_id;

    my $detail = $self->{db}->selectrow_hashref("SELECT csd.* FROM corp_starbase_detail csd WHERE starbase_id = ?", { Slice => {} }, $starbase_id );

    return {} if ref $detail ne 'HASH';

    $detail->{fuel} = $self->{db}->selectall_arrayref("SELECT csdf.*,
                                        ( SELECT typeName FROM evedeliveries.invTypes WHERE typeID = csdf.type_id ) as type_name
                                         FROM corp_starbase_detail_fuel csdf WHERE starbase_id = ?", { Slice => {} }, $starbase_id ) || [];
    return $detail;
}

sub set_starbase_list {
    my ( $self, $key, $vcode ) = @_;

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $starbases;
    $starbases = $eapi->starbase_list();

    return 1 if defined $starbases->{error} || ! $starbases;

    if ( scalar keys %$starbases > 0 ) {
        my $db_sbs = [];
        my $api_sbs = [];
        foreach my $item_id ( keys %$starbases ) {
            next if $item_id eq 'cached_until';

            my $exist_sb = $self->{db}->selectrow_array("SELECT id FROM corp_starbase_list WHERE item_id = ? or moon_id = ?", undef, $item_id, $starbases->{$item_id}->{moonID} );
            
            push @$db_sbs, $exist_sb;
            push @$api_sbs, $item_id;

            unless ( $exist_sb ) {
                $self->{db}->do("INSERT INTO corp_starbase_list SET
                            corp_key_id = ?,
                            item_id     = ?,
                            moon_id     = ?,
                            location_id = ?,
                            type_id     = ?,
                            standing_owner_id = ?,
                            online_timestamp = ?,
                            state_timestamp = ?,
                            state = ?,
                            cached_until = ?
                            ", undef, 
                            $key,
                            $item_id,
                            $starbases->{$item_id}->{moonID} || 0,
                            $starbases->{$item_id}->{locationID} || 0,
                            $starbases->{$item_id}->{typeID} || 0,
                            $starbases->{$item_id}->{standingOwnerID} || 0,
                            $starbases->{$item_id}->{onlineTimestamp} || 0,
                            $starbases->{$item_id}->{stateTimestamp} || 0,
                            $starbases->{$item_id}->{state} || 0,
                            $starbases->{cached_until},
                        );
            }
            else {
                $self->{db}->do("UPDATE corp_starbase_list SET
                            corp_key_id = ?,
                            moon_id     = ?,
                            location_id = ?,
                            type_id     = ?,
                            standing_owner_id = ?,
                            online_timestamp = ?,
                            state_timestamp = ?,
                            state = ?,
                            cached_until = ?,
                            item_id = ?
                            WHERE id = ?
                            ", undef, 
                            $key,
                            $starbases->{$item_id}->{moonID} || 0,
                            $starbases->{$item_id}->{locationID} || 0,
                            $starbases->{$item_id}->{typeID} || 0,
                            $starbases->{$item_id}->{standingOwnerID} || 0,
                            $starbases->{$item_id}->{onlineTimestamp} || 0,
                            $starbases->{$item_id}->{stateTimestamp} || 0,
                            $starbases->{$item_id}->{state} || 0,
                            $starbases->{cached_until},
                            $item_id,
                            $exist_sb
                        );
            }
            $self->set_starbase_detail( $item_id, $key, $vcode );

        }
        my @to_del = subtract_set( $db_sbs, $api_sbs );
        $self->delete_old_starbases( \@to_del );
    }
    return 1;
}

sub delete_old_starbases {
    my ($self, $old_sbs) = @_;
    
    return 1 if ref $old_sbs ne 'ARRAY'; 

    my $list = join(',', @$old_sbs);
    if ( $list ) {
        $self->{db}->do("DELETE FROM corp_starbase_list WHERE item_id IN (?)", undef, $list);
        $self->{db}->do("DELETE FROM corp_starbase_detail WHERE starbase_id IN (?)", undef, $list);
        $self->{db}->do("DELETE FROM corp_starbase_detail_fuel WHERE starbase_id IN (?)", undef, $list);
    }
    
    return 1;
}


sub set_starbase_detail {
    my ( $self, $item_id, $key, $vcode ) = @_;

    my $eapi = Games::EveOnline::API->new( user_id => $key, api_key => $vcode );

    my $details;
    $details = $eapi->starbase_detail( item_id => $item_id );

    return 1 if defined $details->{error} || ! $details;

    $self->{db}->do("DELETE FROM corp_starbase_detail WHERE starbase_id = ?", undef, $item_id);

    $self->{db}->do("INSERT INTO corp_starbase_detail SET
                        starbase_id = ?,
                        online_timestamp = ?,
                        state_timestamp = ?,
                        state = ?,
                        allow_corporation_members = ?,
                        allow_alliance_members = ?,
                        usage_flags = ?,
                        deploy_flags = ?,
                        on_status_drop_standing = ?,
                        on_corporation_war = ?,
                        on_aggression = ?,
                        on_status_drop_enabled = ?,
                        on_standing_drop = ?,
                        use_standings_from = ?,
                        cached_until = ?
                        ", undef, 
                        $item_id,
                        $details->{online_timestamp},
                        $details->{state_timestamp},
                        $details->{state},
                        $details->{general_settings}->{allow_corporation_members},
                        $details->{general_settings}->{allow_alliance_members},
                        $details->{general_settings}->{usage_flags},
                        $details->{general_settings}->{deploy_flags},
                        $details->{combat_settings}->{on_status_drop_standing},
                        $details->{combat_settings}->{on_corporation_war},
                        $details->{combat_settings}->{on_aggression},
                        $details->{combat_settings}->{on_status_drop_enabled},
                        $details->{combat_settings}->{on_standing_drop},
                        $details->{combat_settings}->{use_standings_from},
                        $details->{cached_until},
                    );

    $self->set_starbase_fuel( $item_id, $details->{fuel} );

}

sub set_starbase_fuel {
    my ( $self, $item_id, $fuels ) = @_;

    $self->{db}->do("DELETE FROM corp_starbase_detail_fuel WHERE starbase_id = ?", undef, $item_id);

    foreach my $fuel ( @$fuels ) {
        $self->{db}->do("INSERT INTO corp_starbase_detail_fuel SET starbase_id = ?, type_id = ?, quantity = ?", undef, 
                       $item_id, $fuel->{type_id}, $fuel->{quantity} );
    }

    return 1;
}


1;
