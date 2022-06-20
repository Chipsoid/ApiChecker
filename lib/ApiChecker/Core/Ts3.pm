package ApiChecker::Core::Ts3;

use utf8;
use Modern::Perl;
use Data::Dumper;
use YAML::Tiny;
use POSIX;
use Log::Log4perl;

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

sub list {
    my ($self, $page, $per_page, $by, $order, $search, ) = @_;

    my $order_by = "ORDER BY u.create_date DESC";
    if ( $by ~~ ['client_id','nickname', 'create_date', 'login_count', 'last_login'] ) {
        my $table = ( $by eq 'last_login' ) ? '' : 'u.';
        $order_by = "ORDER BY $table$by $order";
    }

    my $where = ' WHERE 1 = 1 ';
    my $join  = ' ';
    my $select = '(SELECT ip FROM ts3ip t WHERE t.client_id = u.client_id ORDER BY upload_date DESC LIMIT 1 ) as last_ip,';

    if ( ref $search eq 'ARRAY' ) {
        foreach my $rule ( @$search ) {
            $rule->{value} =~ s/\s/+/g;
    
            if ( $rule->{field} eq 'ip' ) {
                $where .=  'AND ts3.' . $rule->{field} . " = '" . $rule->{value} . "' ";
                $join = 'INNER JOIN ts3ip ts3 ON  ts3.client_id = u.client_id';
                $select = 'ts3.ip as last_ip,';
            }
            else {
                $where .=  'AND ' . $rule->{field} . " LIKE '%" . $rule->{value} . "%' ";
            }
        }

    }

    my $limit = " LIMIT ". ( $page * $per_page ) .", $per_page;";

    my $query = "SELECT u.id, u.client_id, REPLACE( u.nickname, '+', ' ') as nickname, u.login_count, FROM_UNIXTIME(u.create_date) as create_date, u.upload_date, 
        $select
        (SELECT FROM_UNIXTIME(last_login) FROM ts3ip t WHERE t.client_id = u.client_id ORDER BY upload_date DESC LIMIT 1 ) as last_login
        FROM ts3users u 
        $join
        $where $order_by $limit";
    
    return $self->{db}->selectall_arrayref($query, { Slice => {} });
}

sub get_ts3_page_count {
    my ( $self, $page, $per_page, $search,  ) = @_;

    my $where = ' WHERE 1 = 1 ';
    my $join  = ' ';
    my $select = '(SELECT ip FROM ts3ip t WHERE t.client_id = u.client_id ORDER BY upload_date DESC LIMIT 1 ) as last_ip,';

    if ( ref $search eq 'ARRAY' ) {
        foreach my $rule ( @$search ) {
            $rule->{value} =~ s/\s/+/g;
    
            if ( $rule->{field} eq 'ip' ) {
                $where .=  'AND ts3.' . $rule->{field} . " = '" . $rule->{value} . "' ";
                $join = 'INNER JOIN ts3ip ts3 ON  ts3.client_id = u.client_id';
                $select = 'ts3.ip as last_ip,';
            }
            else {
                $where .=  'AND ' . $rule->{field} . " LIKE '%" . $rule->{value} . "%' ";
            }
        }

    }

    my $query = "SELECT COUNT(u.id) FROM ts3users u $join $where";

    my $records_count = $self->{db}->selectrow_array($query, undef);
    return ceil( $records_count / $per_page ); 
}

sub get_ips {
    my ( $self, $client_id ) = @_;

    return [] unless $client_id;

    return $self->{db}->selectall_arrayref("SELECT ip, FROM_UNIXTIME(last_login) FROM ts3ip WHERE client_id = ? GROUP BY ip ORDER BY last_login DESC", undef, $client_id);

}

sub get_clients_by_ip {
    my ( $self, $ip ) = @_;

    return [] unless $ip;

    return $self->{db}->selectall_arrayref("SELECT ts3.ip, FROM_UNIXTIME(last_login) as last_login, REPLACE( u.nickname, '+', ' ') as nickname  FROM ts3ip ts3 INNER JOIN ts3users u ON ts3.client_id = u.client_id WHERE ts3.ip = ? GROUP BY ts3.client_id ORDER BY last_login DESC", undef, $ip);
}


1;