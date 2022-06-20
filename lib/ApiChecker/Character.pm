package ApiChecker::Character;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;
#use YAML::XS qw/LoadFile/;

use ApiChecker::Core::User;
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Utils qw( time_diff now );
# This action will render a template
sub index {
	my $self = shift;

    

    $self->render(header => 'Инструменты Большого Брата',  );
}

sub show {
    my $self = shift;

    my ($info, $attributes, $skills, $status, $spoints, $all_chars, $employ_history, $assets_sum, 
        $skill_train, $implants, $jump_clones, $counts);
    my $char_name = '';

    my $char_id = $self->param('id');

    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }
    
    my $api     = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my ($key, $vcode) = $api->get_by_char_id( $char_id );

    $info       = $account->get_character_sheet( $char_id );
    $attributes = $account->get_character_attributes( $char_id );
    $implants   = $account->get_character_implants( $char_id );
    $skills     = $account->get_character_skills( $char_id );
    $spoints    = $account->get_skillpoints( $char_id );
    $status     = $account->get_account_status( $key, $vcode );
    $all_chars  = $account->get_api_key_info( $key );
    $employ_history = $eve->get_employment_history( $char_id );
    $assets_sum  = $account->get_assets_sum($char_id);
    $skill_train = $account->get_character_skill_training( $char_id )->[0];
    $jump_clones = $account->get_character_jump_clones( $char_id );

    $counts      = $account->get_counts( $char_id );

    if ( $status->[0]->{paid_until} && time_diff( $status->[0]->{paid_until}, now() ) > 0 ) {
        $status->[0]->{not_payed} = 1;
    }

    my $skills_info;
    foreach my $skill ( @$skills ) {
        $skills_info->{ $skill->{groupName} }->{points} += $skill->{skill_points};
        $skills_info->{ $skill->{groupName} }->{in_five}++ if $skill->{level} == 5;
    }

    $char_name = $info->{name} || '';
    $self->render( header => 'Информация о пилоте ' . $char_name, info => $info, char_attrs => $attributes, char_skills => $skills, skills_info => $skills_info, account_status => $status, skill_points => $spoints, chars => $all_chars, employ_history => $employ_history, assets_sum => $assets_sum, skill_train => $skill_train, implants => $implants, jump_clones => $jump_clones, counts => $counts );
}

sub assets {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }
    
    my $info       = $account->get_character_sheet( $char_id );
    my $locations  = $account->get_character_assets_locations( $char_id );

    $char_name = $info->{name};

    my $search_result;
    if ( $self->param("asset_name") ) {
        $search_result = $account->get_assets_search( $char_id, $self->param("asset_name") );
    }

    $self->render( header => 'Склады пилота ' . $char_name, char_id => $char_id, locations => $locations, search_result => $search_result, search_name => $self->param("asset_name") || '' );
}

sub assets_list {
    my $self = shift;
    my $char_id = $self->param('id');
    my $loc_id  = $self->param('loc');
    my $contents = $self->param('contents');

    unless ( $char_id =~ /\d{8,}/ ) {
        $self->render( text => 'NO_CHAR_ID' ); return;
    }
    unless ( $loc_id =~ /\d{5,}/ ) {
        $self->render( text => 'NO_LOCATION_ID' ); return;
    }
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $assets = $account->get_character_assets( $char_id, $loc_id, $contents );

    foreach my $asset ( @$assets ) {
        $asset->{icon_path} = '';
        my $icon_file = $asset->{type_id};
        $icon_file = $icon_file . '_32';

        $asset->{icon_path} = '/i/types/' . $icon_file . '.png';
    }
    
    $self->render( json => $assets );
}

sub contracts {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $page        = $self->param('page')  || 0;
       $page        = 0 if $page < 0;
    my $per_page    = $self->param('per_page') || 25;
    my $sort        = $self->param('sort');
    my $by          = $self->param('by')       || 'date';
    
    my $info       = $account->get_character_sheet( $char_id );
    my $contracts   = $account->get_contracts( $char_id, $page, $per_page, $by, $sort );
    my $page_count = $account->get_contracts_page_count( $char_id, $page, $per_page );
    my $char_info  = $eve->get_character_info( data => $contracts, exclude_ids => [$char_id], fields => ['contract_id'] );

    $char_name = $info->{name};

    $self->render( header => 'Контракты пилота ' . $char_name, contracts => $contracts, char_id => $char_id, char_info => $char_info, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by );
}

sub contract_items {
    my $self = shift;

    my $char_id     = $self->param('char_id');
    my $contract_id = $self->param('contract_id');

    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }
    
    my $info       = $account->get_character_sheet( $char_id );
    my $contract_items = $account->get_contract_items( $char_id, $contract_id );

    $self->render( json => $contract_items );
}

sub contacts {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $info       = $account->get_character_sheet( $char_id );
    my $contacts   = $account->get_character_contacts( $char_id );
    my $char_info  = $eve->get_character_info( data => $contacts, exclude_ids => [$char_id], fields => ['contact_id'] );

    $char_name = $info->{name};

    $self->render( header => 'Контакты пилота ' . $char_name, contacts => $contacts, char_id => $char_id, char_info => $char_info );
}

sub journal {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $page        = $self->param('page')  || 0;
       $page        = 0 if $page < 0;
    my $per_page    = $self->param('per_page') || 50;
    my $sort        = $self->param('sort');
    my $by          = $self->param('by')       || 'date';
    my $ref_type_id = $self->param('ref_type_id') || 0;

    
    my $info       = $account->get_character_sheet( $char_id );
    my $journal    = $account->get_wallet_journal( $char_id, $page, $per_page, $by, $sort, $ref_type_id );
    my $page_count = $account->get_journal_page_count(  $char_id, $page, $per_page, $ref_type_id );
    my $ref_types  = $account->get_journal_ref_types( $char_id );
    my $char_info  = $eve->get_character_info( data => $journal, exclude_ids => [$char_id], fields => ['owner_id1','owner_id2', 'arg_id1'] );

    $char_name = $info->{name};

    $self->render( header => 'Кошелёк пилота ' . $char_name, char_name => $char_name, journal => $journal, char_id => $char_id, char_info => $char_info, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by, ref_types => $ref_types, ref_type_id => $ref_type_id );
}

sub transactions {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $page  = $self->param('page')  || 0;
    $page     = 0 if $page < 0;
    my $per_page = $self->param('per_page') || 50;
    my $sort    = $self->param('sort');
    my $by       = $self->param('by')       || 'date';
    
    my $info       = $account->get_character_sheet( $char_id );
    my $transes    = $account->get_wallet_transactions( $char_id, $page, $per_page, $by, $sort );
    my $page_count = $account->get_transactions_page_count(  $char_id, $page, $per_page );
    my $char_info  = $eve->get_character_info( data => $transes, exclude_ids => [$char_id], fields => ['client_id'] );

    $char_name = $info->{name};

    $self->render( header => 'Транзакции пилота ' . $char_name, char_info => $char_info, transes => $transes, char_id => $char_id, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by );
}

sub log {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $page  = $self->param('page')  || 0;
    $page     = 0 if $page < 0;
    my $per_page = $self->param('per_page') || 50;
    my $sort    = $self->param('sort');
    my $by       = $self->param('by')       || 'date';
    
    my $info       = $account->get_character_sheet( $char_id );
    my $logs    = $api->get_logs( $char_id, $page, $per_page, $by, $sort );
    my $page_count = $api->get_logs_page_count(  $char_id, $page, $per_page );

    $char_name = $info->{name};

    $self->render( header => 'Лог АПИ пилота ' . $char_name, logs => $logs, char_id => $char_id, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by );
}

sub mails {
    my $self = shift;

    my $char_id = $self->param('id');
    unless ( $char_id =~ /\d{8,}/ ) {
        $self->redirect_to('/');
    }

    my $char_name = '';
    my $api = ApiChecker::Core::Api->new( $self->stash('db') );
    my $eve     = ApiChecker::Core::Eve->new( $self->stash('db'), $api );
    my $account;
    if ( grep { $_ eq 'admin' } keys $self->session('roles') ) {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api );
    }
    else {
        $account = ApiChecker::Core::Account->new( $self->stash('db'), $api, $self->session('id') );

        unless ($account->is_my_char( $char_id ) ) {
            $self->redirect_to('/');
            return;
        }
    }

    my $page  = $self->param('page')  || 0;
    $page     = 0 if $page < 0;
    my $per_page = $self->param('per_page') || 50;
    my $page_count = $account->get_mails_page_count(  $char_id, $per_page );
    my $sort    = $self->param('sort');
    my $by       = $self->param('by')       || 'date';
    
    my $info       = $account->get_character_sheet( $char_id );
    my $mails      = $account->get_mails( $char_id, $page, $per_page, $by, $sort );
    my $mail_lists = $account->get_mail_lists( $char_id );
    my $char_info  = $eve->get_character_info( data => $mails, exclude_ids => [$char_id], fields => ['sender_id','to_character_ids'] );

    $char_name = $info->{name};

    $self->render( header => 'Почта пилота ' . $char_name, mails => $mails, char_id => $char_id, mail_lists => $mail_lists, char_info => $char_info, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by );
}


1;
