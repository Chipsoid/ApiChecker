package ApiChecker::Starbase;
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

    my $list = $corp->get_starbase_list();

    my $states = ['Unanchored','Anchored / Offline','Onlining','Reinforced','Online'];

    foreach my $sb ( @$list ) {
        $sb->{state_name} = $states->[$sb->{state}];
    }

    $self->render( header => 'Просмотр ПОСов', starbases => $list ); 
}


sub moons {
    my $self = shift;

    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );

    if ( $self->req->method eq 'POST' ) {
        my $moon_id   = $self->param("moon_id");
        my $moon_mat  = $self->param("moon_mat");

        $eve->set_moon_mat( $moon_id, $moon_mat );
    }

    my $moon_mats = $eve->get_moon_mats();
    my $khown_moons = $eve->get_khown_moons(); 

    $self->render( header => 'Просмотр лун', moon_mats => $moon_mats, moons => $khown_moons ); 

}

sub find_moon {
    my $self = shift;

    my $name = $self->param("moon_name");

    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );

    my $result = $eve->find_moons( $name );

    $self->render( json => $result );
}

sub edit_moon {
    my $self = shift;

    my $name = $self->param("moon_name");

    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );

    if ( $self->req->method eq 'POST' ) {
        my $uniq_id   = $self->param("moon_uniq_id");
        my $moon_mat  = $self->param("moon_mat");

        $eve->edit_moon_mat( $uniq_id, $moon_mat );
    }

    $self->redirect_to('/starbase/moons');
}

sub del_moon {
    my $self = shift;

    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );

    my $id      = $self->param("id");

    $eve->del_moon_mat( $id );

    $self->redirect_to('/starbase/moons');

}


1;
