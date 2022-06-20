package ApiChecker::Contracts;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;
use YAML::Tiny;

use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Utils qw( time_diff now );

sub index {
    my $self = shift;

    my $chars = YAML::Tiny->read( '/www/api_checker/config/cranb_chars.yaml' )->[0];
    my ($info, $contracts);
    my @output;

    foreach my $char_id ( @$chars) {
        my $api = ApiChecker::Core::Api->new( $self->stash('db') );
        my $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );

        $info       = $account->get_character_sheet( $char_id );
        $contracts   = $account->get_contracts( $char_id );
        my @valid_contracts;
        map { push @valid_contracts, $_ if $_->{status} eq 'Outstanding' && $_->{availability} eq 'Public' } @$contracts;
        next if !@valid_contracts;

        push @output, { name => $info->{name}, contracts => \@valid_contracts, char_id => $char_id };
    }

    $self->render( output => \@output );
}



1;