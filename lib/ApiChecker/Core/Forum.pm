package ApiChecker::Core::Forum;

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

    my $order_by = "ORDER BY f.username DESC";
    if ( $by ~~ ['userid','username', 'last_ip'] ) {
        my $table = ( $by eq 'last_ip' ) ? '' : 'f.';
        $order_by = "ORDER BY $table$by $order";
    }

    my $where = ' WHERE 1 = 1 ';
    my $join  = ' ';

    if ( ref $search eq 'ARRAY' ) {
        foreach my $rule ( @$search ) {
            $rule->{value} =~ s/\s/+/g;
    
            if ( $rule->{field} eq 'ip' ) {
                $where .=  'AND fv.' . $rule->{field} . " = '" . $rule->{value} . "' ";
                $join = 'INNER JOIN forum_users_visits fv ON fv.userid = f.userid';
                #$select = 'fu.ip as last_ip,';
            }
            else {
                $where .=  'AND f.' . $rule->{field} . " LIKE '%" . $rule->{value} . "%' ";
            }
        }
    }

    my $limit = " LIMIT ". ( $page * $per_page ) .", $per_page;";

    my $query = "SELECT *,
        (SELECT ip FROM forum_users_visits fu WHERE f.userid = fu.userid ORDER BY date DESC LIMIT 1 ) as last_ip
        FROM forum_users f 
        $join
        $where $order_by $limit";

    return $self->{db}->selectall_arrayref($query, { Slice => {} });
}

sub get_forum_page_count {
    my ( $self, $page, $per_page, $search,  ) = @_;

    my $where = ' WHERE 1 = 1 ';
    my $join  = ' ';

    if ( ref $search eq 'ARRAY' ) {
        foreach my $rule ( @$search ) {
            $rule->{value} =~ s/\s/+/g;

            if ( $rule->{field} eq 'ip' ) {
                $where .=  'AND fv.' . $rule->{field} . " = '" . $rule->{value} . "' ";
                $join = 'INNER JOIN forum_users_visits fv ON fv.userid = f.userid';
                #$select = 'fu.ip as last_ip,';
            }
            else {
                $where .=  'AND f.' . $rule->{field} . " LIKE '%" . $rule->{value} . "%' ";
            }
        }
    }

    my $query = "SELECT COUNT(f.userid) FROM forum_users f $join $where";

    my $records_count = $self->{db}->selectrow_array($query, undef);
    return ceil( $records_count / $per_page ); 
}

sub get_ips {
    my ( $self, $userid ) = @_;

    return [] unless $userid;

    return $self->{db}->selectall_arrayref("SELECT ip, `date` FROM forum_users_visits WHERE userid = ? GROUP BY ip ORDER BY `date` DESC", undef, $userid);

}

sub get_clients_by_ip {
    my ( $self, $ip ) = @_;

    return [] unless $ip;

    return $self->{db}->selectall_arrayref("SELECT fv.ip, f.username  FROM forum_users_visits fv INNER JOIN forum_users f ON fv.userid = f.userid WHERE fv.ip = ? GROUP BY fv.userid ORDER BY fv.date DESC", undef, $ip);
}


1;