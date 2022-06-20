package ApiChecker::Forum;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use YAML::Tiny;
use Data::Dumper;

use Mojo::Upload;

use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Files;
use ApiChecker::Core::Forum;
use ApiChecker::Core::Utils qw( time_diff now );

sub index {
    my $self = shift;

    my $forum = ApiChecker::Core::Forum->new( $self->stash('db') );

    my $page        = $self->param('page')  || 0;
       $page        = 0 if $page < 0;
    my $per_page    = $self->param('per_page') || 50;
    my $sort        = $self->param('sort');
    my $by          = $self->param('by')       || 'date';

    my $search = [];
    foreach my $search_key ( qw/ username ip / ) {
        if ( $self->param( 'search_' . $search_key ) && $self->param(  'search_' . $search_key ) ne '' ) {
            push @$search, { field => $search_key, value => $self->param(  'search_' . $search_key ) };
        }
    }

    my $user_list = $forum->list( $page, $per_page, $by, $sort, $search,  );
    my $page_count = $forum->get_forum_page_count( $page, $per_page, $search,  );

    if ( $search && scalar @$search > 0 ) {
        $search = { map{ $_->{field} => $_->{value} } @$search };
    }



    $self->render( header => 'Пользователи Forum', search => $search, user_list => $user_list, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by, );
}

sub ips {
    my $self = shift;

    my $userid = $self->param('userid');
    
    my $forum = ApiChecker::Core::Forum->new( $self->stash('db') );

    my $ips = $forum->get_ips( $userid );

    $self->render( json => $ips );

}


1;
