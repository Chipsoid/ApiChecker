package ApiChecker::Main;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;

use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Utils qw( time_diff now );

sub index {
	my $self = shift;
    my $favorites = shift || 0;

    unless ( $self->req->headers->host ~~ ['api.sfsw.ru','api.evekill.info', 'localhost:3000', '172.17.0.3:3000'] ) {
        return $self->reply->not_found;
    }

    my @errors = $self->session('errors');

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );

    my $account;

    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );
    }

    my $search = [];
    foreach my $search_key ( qw/ key_id character_id character_name corporation_name alliance_name / ) {
        if ( $self->param( 'search_' . $search_key ) && $self->param(  'search_' . $search_key ) ne '' ) {
            push @$search, { field => $search_key, value => $self->param(  'search_' . $search_key ) };
        }
    }

    my $page  = $self->param('page')  || 0;
    $page     = 0 if $page < 0;
    my $per_page = $self->param('per_page') || 10;
    my $sort    = $self->param('sort');
    my $by       = $self->param('by')       || 'date';
    my $tag_types = ['grey', 'red', 'green', 'blue', 'purple']; # TODO: Change to select from DB
    
    my $page_count;
    my $accounts;

    $page_count = $account->get_accounts_page_count( $page, $per_page, $search, $favorites );
    $accounts = $account->list( $page, $per_page, $by, $sort, $search, $self->session('id'), $favorites );


    foreach my $acc ( @$accounts ) {
        if ( time_diff( $acc->{paid_until}, now() ) > 0 ) {
            $acc->{not_payed} = 1;
        }
    }

    if ( $search && scalar @$search > 0 ) {
        $search = { map{ $_->{field} => $_->{value} } @$search };
    }

    $self->render(header => 'Инструменты Большого Брата', accounts => $accounts,  errors => @errors, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by, search => $search, tag_types => $tag_types );
}

sub favorites {
    my $self = shift;

    &index( $self, $self->session('id') );
}

sub favorites_add {
    my $self = shift;

    my $char_id = $self->param('id');
    my $user_id = $self->session('id');
    
    my $user = ApiChecker::Core::User->new( $self->stash('db') );

    my $status = $user->favorite_add( $char_id, $user_id );

    $self->render( json => $status );
}

sub bigboys {
    # groupID = 30 Titans, 659 = SuperCarrier
    # typeIDs = 671, 3764, 11567, 23773, 42126, 3514, 3628, 22852, 23913, 23917, 23919, 42125

    my $self = shift;

    my @errors = $self->session('errors');

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );

    my $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );

    my $search = [];
    foreach my $search_key ( qw/ key_id character_id character_name corporation_name alliance_name / ) {
        if ( $self->param( 'search_' . $search_key ) && $self->param(  'search_' . $search_key ) ne '' ) {
            push @$search, { field => $search_key, value => $self->param(  'search_' . $search_key ) };
        }
    }

    my $page  = $self->param('page')  || 0;
    $page     = 0 if $page < 0;
    my $per_page = $self->param('per_page') || 500;
    my $page_count = $account->get_accounts_page_count( $page, $per_page, $search, 0, 1 );
    my $sort    = $self->param('sort');
    my $by       = $self->param('by')       || 'date';

    my $accounts = $account->list( $page, $per_page, $by, $sort, $search, $self->session('id'), 0, 1 );
    $accounts = $account->get_supers( $accounts );

    foreach my $acc ( @$accounts ) {
        if ( time_diff( $acc->{paid_until}, now() ) > 0 ) {
            $acc->{not_payed} = 1;
        }
    }

    if ( $search && scalar @$search > 0 ) {
        $search = { map{ $_->{field} => $_->{value} } @$search };
    }

    $self->render(header => 'Мазера и Титаны Всея СФ', accounts => $accounts,  errors => @errors, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by, search => $search );
}

sub change_bigboy {
    my $self = shift;

    my $char_id = $self->param('id');
    my $value   = $self->param('value');

    my $user = ApiChecker::Core::User->new( $self->stash('db') );
        
    my $status = $user->change_bigboy( $char_id, $value );

    $self->render( json => $status );
}

sub tags_change {
    my $self = shift;

    my $char_id = $self->param('id');
    my $tag_id  = $self->param('tag');
    my $user_id = $self->session('id');
    
    my $user = ApiChecker::Core::User->new( $self->stash('db') );

    my $status = $user->tag_change( $char_id, $user_id, $tag_id );

    $self->render( json => $status );
}


sub favorites_del {
    my $self = shift;

    my $char_id = $self->param('id');
    my $user_id = $self->session('id');
    
    my $user = ApiChecker::Core::User->new( $self->stash('db') );

    my $status = $user->favorite_del( $char_id, $user_id );

    $self->render( json => $status );
}

sub login {
    my $self = shift;

    unless ( $self->req->headers->host ~~ ['api.sfsw.ru','api.evekill.info', 'localhost:3000', '172.17.0.3:3000'] ) {
        return $self->reply->not_found;
    }

    my $login = $self->param('login') || '';
    my $pass  = $self->param('password') || '';

    my $user = ApiChecker::Core::User->new( $self->stash('db') );

    if ( $self->req->method eq 'POST' ) {
        if ( my $id = $user->validate_user( $login, $pass ) ) {
            $self->session( id    => $id );
            $self->session( name  => $login );
            $self->session( roles => $user->get_roles( $id ) );
            $user->logged_user( $id );
            $self->redirect_to('/');
        }
        else {
            $self->render( message => 'То ли логин, то ли пароль... Сами разбирайтесь.' );
        }
    }
}

sub logout {
    my $self = shift;
    $self->session( expires => 1 );
    $self->redirect_to('/login');
}


sub add_api {
    my $self = shift;

    my $status = 'ERROR';

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );

    if ( $self->param('key') && $self->param('vcode') ) {
        my $input_key;
        $input_key = $1 if $self->param('key') =~ /(\d+)/;
        if ( $input_key && $self->param('vcode') && $input_key =~ /^\d+$/ && length( $self->param('vcode') ) == 64 ) {


            # запись ключа
            my $info = $account->set_api_key_info( $input_key, $self->param('vcode') );
            if ( $info != 1 ) {
                $status = 'Не удалось записать данные о ключе в базу';
            }
            else {
                $info = $account->get_api_key_info( $input_key )->[0];
                if ( defined $info->{type} ) {
                    if ( $info->{type} eq 'Account' ) {

                        unless ( $api->save( $input_key, $self->param('vcode'), '-1', $info->{access_mask}, $info->{type} ) ) {
                            $status = 'Не удалось записать ключ';
                        }
                        else {
                            $account->set_account_status( $input_key, $self->param('vcode') );

                            my $chars = $account->get_api_key_info( $input_key );

                            system("perl /www/api_checker/script/cron/api.pl --key=". $input_key ." &");
                            $status = 'success';
                        }
                    }
                    elsif ( $info->{type} ne 'Account' ) {
                        $status = 'Тип ключа не Account';
                    }
                    if ( $info->{access_mask} != 4294967295 ) { 
                        $status = 'Не full-api ключ';
                    }
                }
                else {
                    $status = 'Данные не получены';
                }
            }
        }
        else {
            $status = 'Ключ или код имеют неверный формат';
        }
    }

    $self->render( json => $status );
}

1;
