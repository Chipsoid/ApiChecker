package ApiChecker::Assets;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;


use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Utils qw( time_diff now );

sub index {
    my $self = shift;

    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account;
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );

    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );
    }

    my $loc_names  = $account->get_all_loc_names();
    my $corp_names = $eve->get_all_corp_names();
    
    my $search_result;
    if ( $self->param("asset_name") ) {
        $search_result = $account->get_assets_search_all( $self->param("asset_name"), $self->param('location'), $self->param('corp') );
    }

    $self->render( header => 'Поиск по ассетам пилотов', loc_names => $loc_names, search_result => $search_result, search_name => $self->param("asset_name") || '', location => $self->param('location') || '', corp => $self->param('corp') || '', corp_names => $corp_names );
}



1;
