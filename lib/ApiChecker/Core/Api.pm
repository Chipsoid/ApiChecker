package ApiChecker::Core::Api;

use utf8;
use Modern::Perl;
use Data::Dumper;
use YAML::Tiny;
use POSIX;

sub new {
    my $class = shift;
    my $db = shift;
    $class = ref ($class) || $class;

    my $self;
    $self = {
        db   => $db,
        urls => YAML::Tiny->read( '/www/api_checker/config/api_func.conf.yaml' )->[0],
    };

    bless $self, $class;
    return $self;
}


sub add_api_log {
    my ( $self, $func, $data, $key, $char_id ) = @_;

    my $status = defined $data->{error} ? 'FAIL' : 'OK';
    my $error_text = '';
    my $url = $self->{urls}->{$func} || 'unknown';

    if ( defined $data->{error} ) {
        $error_text = $data->{error}->{content};
        $status = $status . ' ' . $data->{error}->{code};
    }

    $self->{db}->do("INSERT INTO api_log (key_id, url, character_id, `status`, `content`, `date`) 
                     VALUES (?, ?, ?, ?, ?, NOW() )", undef,
                    $key || 0, $url, $char_id || 0, $status, $error_text );
}

sub get_logs_page_count {
    my ( $self, $char_id, $page, $per_page ) = @_;

    my $records_count = $self->{db}->selectall_arrayref("SELECT COUNT(id) FROM api_log WHERE character_id = ?", undef, $char_id);
    return ceil( scalar @$records_count / $per_page ); 
}


sub get_logs {
    my ( $self, $char_id, $page, $per_page, $by, $order ) = @_;

    return {} unless $char_id;

    $order ||= 'DESC';
    my $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";

    my $order_by = "ORDER BY `date` $order";
    if ( $by ~~ ['date','status', 'url', 'content'] ) {
        $order_by = "ORDER BY $by $order";
    }

    my $logs = $self->{db}->selectall_arrayref( "SELECT * FROM api_log WHERE character_id = ? $order_by $offset", { Slice => {} }, $char_id );

    return $logs;
}

sub get_by_char_id {
    my ( $self, $char_id) = @_;

    return unless $char_id;

    my ( $key, $vcode ) = $self->{db}->selectrow_array( "SELECT a.key, a.vcode FROM api a INNER JOIN api_key_info aki ON aki.key_id = a.key WHERE aki.character_id = ? and a.status = 1 and a.deleted = 0 AND aki.type != 'Corporation'", undef, $char_id );

    return ( $key, $vcode );
}

sub char_exists {
    my ( $self, $char_id) = @_;

    return unless $char_id;

    my ( $key ) = $self->{db}->selectrow_array( "SELECT a.key FROM api a INNER JOIN api_key_info aki ON aki.key_id = a.key WHERE a.status = 1 AND aki.character_id = ? and a.deleted = 0 AND aki.type != 'Corporation'", undef, $char_id );

    return $key;
}

sub get_api_count {
    my ( $self, $per_page, $owner ) = @_;

    $owner ||= '';

    if ( $owner ) {
        $owner = ' AND user_id = ' . $owner;
    }

    my $records_count = $self->{db}->selectrow_array("SELECT COUNT(`key`) FROM api a WHERE a.deleted = 0 AND a.status = 1 $owner", undef);

    return ceil( $records_count / $per_page );

}

sub save {
    my ($self, $key, $vcode, $user_id, $mask, $type) = @_;

    return unless $key && $vcode && $user_id && $mask;

    my $key_id = $self->{db}->selectrow_array("SELECT `key` FROM `api` WHERE `key` = ? AND vcode = ? AND deleted = 0;", undef, $key, $vcode);

    return 1 if $key_id;

    $self->{db}->do("INSERT INTO `api` (`key`, `vcode`, `user_id`, `status`, `mask`, `added`, `type`) VALUES (?, ?, ?, 1, ?, NOW(), ? );", undef, $key, $vcode, $user_id, $mask, $type);

    return 1;
}

sub list {
    my ($self, $status, $page, $per_page, $by, $order, $owner) = @_;

    $owner ||= '';

    $status ||= '';
    if ( $status ) {
        $status = ' AND status = 1';
    }

    my $offset = '';
    my $order_by = "ORDER BY a.added DESC";

    if ( defined $page && $per_page ) {
        $offset = " LIMIT ". ( $page * $per_page ) .", $per_page;";
    }

    if ( $by && $by ~~ ['added', 'user_id', 'broken_at', 'status', 'key', 'mask', 'type'] ) {
        $order_by = "ORDER BY a.`$by` $order";
    }

    if ( $owner ) {
        $owner = ' AND user_id = ' . $owner;
    }

    return $self->{db}->selectall_arrayref("SELECT a.*, ( SELECT GROUP_CONCAT( character_name SEPARATOR ',' ) as pilots FROM api_key_info aki WHERE aki.key_id = a.key ) as pilots, ( SELECT login FROM users u WHERE a.user_id = u.id ) as added_by FROM api a WHERE deleted = 0 $status $owner $order_by $offset", { Slice => {} } ) || [];
}


sub corp_list {
    my ($self) = @_;

    return $self->{db}->selectall_arrayref("select * from api where `type` = 'Corporation';", { Slice => {} } ) || [];
}

sub update_status {
    my ($self,  $status, $key) = @_;

    return unless $key;

    return $self->{db}->do("UPDATE `api` SET `status` = ?, `broken_at` = NOW() WHERE `key` = ?;", undef, $status, $key);
}

sub remove_key {
    my ($self, $key) = @_;

    return unless $key;
    $self->{db}->do("UPDATE `api` SET deleted = 1 WHERE `key` = ?;", undef, $key);
    return 1;
}

sub check_same_api {
    my ($self, $char_id) = @_;

    return unless $char_id;
    
    my $existed_char_id = 0;
    $existed_char_id =  $self->{db}->selectcol_arrayref("SELECT aki.character_id 
        FROM api_key_info aki 
        LEFT JOIN api a ON a.key = aki.key_id 
        WHERE a.deleted = 0 AND a.status = 1 AND aki.character_id = ? AND aki.type != 'Corporation';" , undef, $char_id);

    return $existed_char_id == $char_id ? 1 : 0;
}

1;