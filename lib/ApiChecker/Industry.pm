package ApiChecker::Industry;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;

use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Corp;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Utils qw( time_diff now );

sub index {
    my $self = shift;

    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $corp    = ApiChecker::Core::Corp->new( $self->stash('db'), $api );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );

    my $list = $corp->get_industry_jobs();

   
    $self->render( header => 'Производство', industry => $list ); 
}


1;
