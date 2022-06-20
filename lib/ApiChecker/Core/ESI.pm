package ApiChecker::Core::ESI;

use utf8;
use POSIX;
use Modern::Perl;
use Data::Dumper;
use JSON::XS;
use YAML::Tiny;
use List::MoreUtils qw/ uniq /;

use ApiChecker::Core::Utils qw( epoch2mydate );

use lib '/www/EveOnline-SSO/lib';

use EveOnline::SSO;
use EveOnline::SSO::Client;


sub new {
    my $class = shift;
    my $db    = shift;
    my $char_id = shift;

    return unless $db || $char_id;

    $class = ref ($class) || $class;

    my $self;
    $self = {
        db  => $db,
        esi => YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0]->{esi},
        char_id => $char_id,
    };

    bless $self, $class;

    $self->{client} = $self->init_client();

    return $self;
}

sub init_client {
    my ($self) = @_;

    my $refresh_token = $self->get_or_refresh_token($self->{char_id});
    $refresh_token = $self->get_or_refresh_token($self->{char_id}) unless $refresh_token;
    return $self->init_client_connect($refresh_token);
}

sub init_sso_connect {
    my $self = shift;

    return EveOnline::SSO->new(client_id => $self->{esi}->{client_id}, client_secret => $self->{esi}->{client_secret});
}

sub init_client_connect {
    my $self = shift;
    my $token = shift;

    return unless $token;

    return EveOnline::SSO::Client->new(token=>$token, x_user_agent => 'Chips Merkaba <kaachips@gmail.com> Api-Checker');
}

sub get_or_refresh_token {
    my ($self) = @_;

    my $token_exist = $self->{db}->selectall_arrayref("SELECT access_token, refresh_token, IF( expires_in <= NOW(), 1, 0) as expired FROM api_key_info aki WHERE aki.character_id = ? LIMIT 1;", { Slice => {}}, $self->{char_id});

    $token_exist = $token_exist->[0];

    # say Dumper $token_exist;

    if ( defined $token_exist && ( $token_exist->{expired} == 1 || ! $token_exist->{access_token} ) ) {

        if ( $token_exist->{refresh_token} ) {
            my $data = $self->get_token($token_exist->{refresh_token});
            $self->save_token($data->{access_token}, $data->{refresh_token});
            return $data->{access_token};
        }
        return;
    }
    
    return $token_exist->{access_token};
}

sub get_token {
    my ($self, $refresh_token) = @_;

    return unless $refresh_token;

    my $sso = $self->init_sso_connect();

    return $sso->get_token(refresh_token=>$refresh_token);
}

sub save_token {
    my ($self, $access_token, $refresh_token) = @_;

    return unless $access_token || $refresh_token;

    # say Dumper ($access_token, $refresh_token);

    $self->{db}->do("UPDATE api_key_info SET access_token = ?, refresh_token = ?, expires_in = DATE_ADD(NOW(), INTERVAL 1200 SECOND) WHERE `character_id` = ?", undef, $access_token, $refresh_token, $self->{char_id});
}

sub get_universe_structure_id {
    my ($self, $structure_id) = @_;

    return unless $structure_id;

    my $data = $self->{client}->get(['universe','structures',$structure_id]);

    return $data;
}

sub set_structure_id {
    my ($self, $structure_id, $data) = @_;

    return unless $structure_id || $data;

    $self->{db}->do("REPLACE structures (structure_id, solar_system_id, type_id, name, x, y, z) VALUES (?, ?, ?, ?, ?, ?, ?)", undef,
        $structure_id, $data->{solar_system_id}, $data->{type_id}, $data->{name}, $data->{position}->{x}, $data->{position}->{y}, $data->{position}->{z});

    return 1;
}


sub set_facilities {
    my ($self) = @_;

    my $facilities = $self->{client}->get(['industry','facilities']);

    my $sql_facs = [];
    foreach my $fac (@$facilities) {
        push @$sql_facs, '('.$fac->{facility_id}.','.$fac->{owner_id}.','.$fac->{region_id}.','.$fac->{solar_system_id}.','.( $fac->{tax} || 0 ).','.$fac->{type_id}.')';
    }

    # say Dumper $facilities;

    # $self->{db}->do("REPLACE facilities (facility_id, owner_id, region_id, solar_system_id, tax, type_id) VALUES " . join ',', @$sql_facs);

    return 1;
}


1;