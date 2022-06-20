package ApiChecker::Core::IP;

use utf8;
use Modern::Perl;
use Data::Dumper;
use YAML::Tiny;
use JSON::XS;
use LWP::UserAgent;

use Yandex::Metrika;

BEGIN {
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}

sub new {
    my $class = shift;
    my $db = shift;
    $class = ref ($class) || $class;

    my $self;
    $self = {
        db => $db,
    };

    bless $self, $class;
    return $self;
}

sub get_metrika_user_vars {
    my ( $self, $params ) = @_;

    my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0]->{yandex}->{metrika};

    my $metrika = Yandex::Metrika->new( token => $conf->{access_token}, counter => $conf->{counter} );
    $metrika->set_per_page( 500 );
    $metrika->set_pretty( 1 );

    my $data = $metrika->user_vars({ date1 => $params->{data1}, date2 => $params->{data2}, table_mode => 'tree', group => 'all' });

    my @id_ip;
    
    push @id_ip, $self->_parse_metrika_vars( $data );


    while ( $metrika->next_url ) {
        $data = $metrika->user_vars({next => 1});
        push @id_ip, $self->_parse_metrika_vars( $data );
    }

    $self->save_metrika_vars( \@id_ip );


}

sub save_metrika_vars {
    my ( $self, $visits ) = @_;

    foreach my $visit ( @$visits ) {
        if ( $self->{db}->selectrow_array("SELECT id FROM forum_users_visits fuv WHERE userid = ? AND ip = ?", undef, $visit->[0], $visit->[1] ) ) {
            next;
        }

        $self->{db}->do("INSERT INTO forum_users_visits ( userid, `date`, `ip` ) VALUES ( ?, NOW(), ?)", undef, $visit->[0], $visit->[1] || '' );
    }
    
    return 1;
}

sub _parse_metrika_vars {
    my ( $self, $data ) = @_;

    my @id_ip;

    foreach my $node ( @{ $data->{data} } ) {
        next unless $node->{name} eq 'idip';

        foreach my $visit ( @{ $node->{chld} } ) {
            next if $visit->{name} =~ /^\d$/;

            push @id_ip, [ split /\+/, $visit->{name} ];
        }
    }
    return @id_ip;
}


sub decode_ts3_answer {
    my ( $self, $content ) = @_;

    return JSON::XS::decode_json( $content );

}

sub read_content {
    my ( $self, $path ) = @_;

    my $content;
    open(my $JS, '<', $path);
    $content .= $_ while <$JS>;
    close $JS;

    return $self->decode_ts3_answer($content);
}

sub download_ts3_data {
    my ( $self ) = @_;

    my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0];

    my $dbh = DBI->connect($conf->{ts3_db}->{dsn} . ";host=".$conf->{ts3_db}->{host}, $conf->{ts3_db}->{username}, $conf->{ts3_db}->{password}, {
          PrintError => 1,
          AutoCommit => 1,
          'RaiseError' => 1,
          'mysql_enable_utf8' => 1,
    });

    my $res = $dbh->selectall_arrayref("select client_id, client_unique_id, client_nickname, client_totalconnections, (SELECT value from client_properties where ident = 'client_created' and id = client_id ) as created, client_lastconnected, client_lastip from clients;", { Slice => {} });

    return $res;
}

sub update_ts3_users {
    my ( $self, $users ) = @_;

    foreach my $user ( @$users ) {
        if ( $self->{db}->selectrow_array("SELECT client_id FROM ts3users WHERE client_id = ?", undef, $user->{client_id}) ) {
            $self->{db}->do("UPDATE ts3users SET login_count = ? WHERE client_id = ?", undef, $user->{client_totalconnections}, $user->{client_id});
            next;
        }
        $self->{db}->do("INSERT INTO ts3users (client_id, unique_id, nickname, create_date, `login_count`, `upload_date`) VALUES 
            (?, ?, ?, ?, ?,  NOW())", undef, 
            $user->{client_id},
            $user->{client_unique_id},
            $user->{client_nickname},
            $user->{created} || '0',
            $user->{client_totalconnections}, );
    }

    return 1;
}

sub update_ts3_users_ip {
    my ( $self, $users ) = @_;

    foreach my $user ( @$users ) {
        if ( $self->{db}->selectrow_array("SELECT client_id FROM ts3ip WHERE client_id = ? AND last_login = ?", undef, $user->{client_id}, $user->{client_lastconnected}) ) {
            next;
        }

        $self->{db}->do("INSERT INTO ts3ip (client_id, last_login, ip, upload_date) VALUES 
            (?, ?, ?,  NOW())", undef, 
            $user->{client_id},
            $user->{client_lastconnected},
            $user->{client_lastip} || '', );
    }

    return 1;
}


1;