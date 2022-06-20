package ApiChecker::Api;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;
use Mojo::Headers;

use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;

# use ApiChecker::Core::ESI;

# This action will render a template
sub index {
	my $self = shift;

    # my $esi = ApiChecker::Core::ESI->new( $self->stash('db'), 90922771 );

    my @errors = $self->session('errors');

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );

    my $page  = $self->param('page')  || 0;
    $page     = 0 if $page < 0;
    my $per_page = $self->param('per_page') || 25;
    my $page_count;
    my $sort       = $self->param('sort');
    my $by         = $self->param('by')     || 'date';

    my $apis;

    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $apis = $api->list( 0, $page, $per_page, $by, $sort );
        $page_count = $api->get_api_count( $per_page );
    }
    else {
        $apis = $api->list( 0, $page, $per_page, $by, $sort, $self->session('id') );
        $page_count = $api->get_api_count( $per_page, $self->session('id') );
    }
    

    foreach my $a ( @$apis ) {

        my @pilots = split ',',  $a->{pilots};
        foreach my $pilot ( @pilots ) {

            my $char_id = $account->get_char_id_by_name( $pilot );
            push @{ $a->{pilots_info} }, [ $char_id, $pilot ];
        }
    }
    #say Dumper $apis;
    $self->render(header => 'Управление API-ключами', errors => @errors, apis => $apis, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by );
}

sub add {
    my $self = shift;

    my @errors = $self->session('errors');

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );

    @errors = ();
    my $input_key;

    $input_key = $1 if $self->param('key') =~ /(\d+)/;
    if ( $input_key && $self->param('vcode') && $input_key =~ /^\d+$/ && length( $self->param('vcode') ) == 64 ) {

        my $info = $account->set_api_key_info( $input_key, $self->param('vcode') );
        if ( $info != 1 ) {
            push @errors, { text => 'Не удалось записать данные о ключе в базу', type => 'danger' };
        }
        else {
            $info = $account->get_api_key_info( $input_key )->[0];
            if ( defined $info->{type} ) {
                if ( $info->{type} ~~ ['Account', 'Corporation'] ) {

                    unless ( $api->save( $input_key, $self->param('vcode'), $self->session('id'), $info->{access_mask}, $info->{type} ) ) {
                        push @errors, { text => 'Не удалось записать ключ', type => 'danger' };
                    }
                    else {
                        if ( $info->{type} eq 'Account' ) {
                            $account->set_account_status( $input_key, $self->param('vcode') );

                            my $chars = $account->get_api_key_info( $input_key );

                            system("perl /www/api_checker/script/cron/api.pl --key=". $input_key ." &");
                        }

                        push @errors, { text => 'Ключ успешно записан', type => 'success' };
                    }
                }
                elsif ( $info->{type} eq 'Character' ) {
                    push @errors, { text => 'Тип ключа не Account или Corporation', type => 'danger' };
                }
                if ( $info->{type} eq 'Account' && $info->{access_mask} != 4294967295 ) { 
                    push @errors, { text => 'Не full-api ключ', type => 'warning' };
                }
            }
            else {
                push @errors, { text => 'Данные не получены', type => 'warning' };
            }
        }
    }
    else {
        push @errors, { text => 'Ключ или код имеют неверный формат', type => 'danger' };
    }
    $self->session( errors => \@errors );
    $self->redirect_to('/api/' );
}

sub delete {
    my $self = shift;

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );

    my $status;
    if ( $self->param('id') && $self->param('id') =~ /\d+/ ) {
        $status = $api->remove_key( $self->param('id') );
    }
    $self->session( errors => [{text => 'API успешно удалено', type => 'success'}] );
    $self->render( text => 'success' );
}

sub force_update {
    my $self = shift;

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );

    my $headers = $self->req->headers;
    my $referer = $headers->referrer || '/api/';
    my $text    = 'ключа';

    
    my $id = $self->param('id');
    $id = $1 if $id =~ /^c(\d+)$/;

    if ( $self->param('id') =~ /^\d+$/ ) {
        eval { system("perl /www/api_checker/script/cron/api.pl --key=". $id ." --force &"); };
    }
    elsif ( $self->param('id') =~ /^c\d+$/  ) {
        $text = 'персонажа';
        eval { system("perl /www/api_checker/script/cron/api.pl --id=". $id ." --force &"); };
    }

    $self->session( errors => [{text => "Обновление для $text ". $id .' началось', type => 'success'}] );
    $self->redirect_to( $referer );

}



1;
