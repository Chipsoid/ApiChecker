package ApiChecker::Core::User;

use utf8;
use Modern::Perl;
use Data::Dumper;
use YAML::Tiny;
use Log::Log4perl;

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };

Log::Log4perl->init($config);
my $log = Log::Log4perl->get_logger('users');

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

sub get {
    my ( $self, $login ) = @_;

    return unless $login;

    my $exists = $self->{db}->selectrow_array("SELECT id FROM users WHERE login = ?;", undef, $login);
    return $exists;
}

sub get_all_corps {
    my ( $self ) = @_;

    return $self->{db}->selectall_arrayref("SELECT corporation_id, corporation_name, alliance_id, alliance_name FROM api_key_info WHERE alliance_id > 0 GROUP BY corporation_id ORDER BY alliance_name, corporation_name ASC", { Slice => {} }, );
}

sub get_user_corps {
    my ( $self, $user_id ) = @_;

    return $self->{db}->selectcol_arrayref("SELECT corporation_id FROM user_corps WHERE user_id = ?", undef, $user_id);
}

sub set_user_corps {
    my ( $self, $user_id, $corps ) = @_;

    $self->{db}->do("DELETE FROM user_corps WHERE user_id = ?", undef, $user_id);

    foreach my $corp ( @$corps ) {
        $self->{db}->do("INSERT INTO user_corps SET user_id = ?, corporation_id = ?", undef, $user_id, $corp);
    }
    
    return 1;

}

sub get_roles {
    my ( $self, $id ) = @_;

    return unless $id;
    my $roles = $self->{db}->selectcol_arrayref("SELECT role FROM roles WHERE user_id = ?;", undef, $id);
    return  { map { $_ => 1 } @$roles };
}

sub list {
    my ($self) = @_;

    return $self->{db}->selectall_arrayref("SELECT u.*, (SELECT GROUP_CONCAT( role SEPARATOR ', ') FROM roles r WHERE r.user_id = u.id ) as roles FROM users u;", { Slice => {} });
}

sub add {
    my ($self, $login, $password) = @_;

    return unless $login && $password;
    $log->info("Add new user $login");
    return $self->{db}->do("INSERT INTO users (login, password, created, status) VALUES ( ?, MD5(?), NOW(), 1 )", undef, $login, $password);
}

sub remove {
    my ($self, $id) = @_;

    return unless $id;
    $log->info("Delete user $id");
    $self->{db}->do("DELETE FROM users WHERE id = ?;", undef, $id);
    $self->{db}->do("DELETE FROM roles WHERE user_id = ?;", undef, $id);

    return 1;
}

sub update {
    my ($self, $id, $params) = @_;

    return unless $id && $params;

    my @set;
    foreach my $fld ( keys %$params ) {
        push @set, "`$fld` = '" . $params->{$fld} . "'";
    }
    $log->info("Update user $id: ". Dumper $params  );
    return $self->{db}->do("UPDATE users SET " . ( join(',', @set) ) . " WHERE id = ?;", undef, $id) || 0;
}

sub add_role {
    my ($self, $role, $user_id, $comment) = @_;

    return unless $role && $user_id;

    $log->info("Add role '$role' to user $user_id");
    return $self->{db}->do("INSERT INTO roles (role, user_id, comment) VALUES (?, ?, ?);", undef, $role, $user_id, $comment || '') || 0;
}

sub remove_roles {
    my ($self, $user_id) = @_;

    return unless $user_id;

    $log->info("Remove all roles from user $user_id");
    return $self->{db}->do("DELETE FROM roles WHERE user_id = ?;", undef, $user_id) || 0;
}

sub load_user {
    my ($self, $id) = @_;

    return unless $id;

    return $self->{db}->selectrow_array("SELECT login FROM users WHERE id = ? AND status = 1;", undef, $id) || 0;
}

sub validate_user {
    my ($self, $login, $password) = @_;

    return unless $login || $password;

    my $id = $self->{db}->selectrow_array("SELECT id FROM users WHERE login = ? AND password = MD5(?) AND status = 1;", undef, $login, $password );
    $log->info("Validate user $login");
    return $id || 0;
}

sub logged_user {
    my ($self, $id) = @_;

    return unless $id;
    $self->{db}->do("UPDATE users SET last_login = NOW(), login_count = login_count + 1 WHERE id = ?;", undef, $id);
    $log->info("User '$id' logged in");
}

sub check_roles {
    my ( $self, $app ) = @_;

    return unless scalar keys %{ $app->session('roles') };

    my $endpoint = $app->match->stack->[-1];
    my @roles = keys %{$app->session('roles')};

    if ( $endpoint->{controller} ~~ ['users', 'api', 'character','assets','files', 'ts3', 'starbase','corp'] ) {
        return unless $endpoint->{controller} ~~ @roles;
    }

    return 1;
}

sub tag_change {
    my ($self, $char_id, $id, $tag_id) = @_;

    return unless $id && $char_id;
    return unless $id =~ /\d+/ && $char_id =~ /\d+/ && $tag_id =~ /\d+/;

    $self->{db}->do("DELETE FROM tags WHERE character_id = ? AND user_id = ?", undef, $char_id, $id);

    $self->{db}->do("INSERT INTO tags (character_id, user_id, tag_id) VALUES (?, ?, ?) ", undef, $char_id, $id, $tag_id) if $tag_id > 0;

    return $self->{db}->selectrow_array("SELECT color FROM tag_types WHERE id = ?", undef, $tag_id) || 'grey';
}

sub favorite_add {
    my ($self, $char_id, $id) = @_;

    return unless $id && $char_id;
    return unless $id =~ /\d+/ && $char_id =~ /\d+/;

    $self->{db}->do("INSERT INTO favorites (character_id, user_id) VALUES (?, ?) ", undef, $char_id, $id);

    return 1;
}

sub favorite_del {
    my ($self, $char_id, $id) = @_;

    return unless $id && $char_id;
    return unless $id =~ /\d+/ && $char_id =~ /\d+/;

    $self->{db}->do("DELETE FROM favorites WHERE character_id = ? AND user_id = ? ", undef, $char_id, $id);

    return 1;
}

sub change_bigboy {
    my ($self, $char_id, $value) = @_;

    return 0 unless $char_id;
    return 0 unless $char_id =~ /\d+/;
    return 0 unless $value ~~ [0, 1];

    if ( $self->{db}->do("UPDATE character_sheet SET is_bigboy = ? WHERE character_id = ?", undef, $value, $char_id) ) {
        return 1;
    }

    return 0;
}

1;