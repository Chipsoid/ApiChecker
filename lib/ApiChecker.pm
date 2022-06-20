package ApiChecker;
use Mojo::Base 'Mojolicious';
use utf8;
use Modern::Perl;
use Data::Dumper;

use Mojolicious::Plugin::Dbi;

use lib '/www/Games-EveOnline-API/lib';
use lib '/www/games-eveonline-evecentral/lib';
use lib '/www/Mojolicious-Plugin-BootstrapPagination/lib';
use Mojolicious::Plugin::BootstrapPagination;

use ApiChecker::Core::User;
use ApiChecker::Core::Utils;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    #$self->plugin('PODRenderer');

    # $self->app->secret('2k3ujwR8se77XhW7bfmzT6npy');

    $self->plugin('RenderFile');
    $self->plugin('RemoteAddr');

    my $config = $self->plugin('yaml_config', {file => 'config/connect.yaml'});

    $self->plugin('dbi',{'dsn' => $config->{dsn},
		'username' => $config->{username},
		'password' => $config->{password},
		'no_disconnect' => 1,
		'stash_key' => 'db',
		'dbi_attr' => { 'AutoCommit' => 1, 'RaiseError' => 1, 'PrintError' => 1, 'mysql_enable_utf8' => 1 },
		'on_connect_do' =>[ 'SET NAMES UTF8'],
		'requests_per_connection' => 200
    });

    $self->plugin( 'bootstrap_pagination' );

    $self->plugin(tt_renderer => {
        template_options => {
            INCLUDE_PATH => 'templates/',
            COMPILE_DIR  => '/tmp/ttcache/',
            COMPILE_EXT  => '.ttc',
            ENCODING     => 'utf8',
            PRE_DEFINE => {
                Dumper  => \&Dumper,
                time_diff => \&ApiChecker::Core::Utils::time_diff,
                time2datetime => \&ApiChecker::Core::Utils::epoch2mydate,
                isin          => \&ApiChecker::Core::Utils::isin,
            },
            FILTERS => {
                format_sum           => \&ApiChecker::Core::Utils::format_sum,
                format_number_triads => \&ApiChecker::Core::Utils::format_number_triads,
                format_date          => \&ApiChecker::Core::Utils::mydate2rus04,
                format_datetime      => \&ApiChecker::Core::Utils::mydatetime2rus04,
                
            },
            template_options => {
                PRE_CHOMP => 1,
                POST_CHOMP => 1,
                TRIM => 1,
            },
        },
    });
    $self->renderer->default_handler('tt');

	# Router
	my $r = $self->routes;

    my $auth = $r->under('/')->to(cb => sub {
        my $self = shift;

        unless ( $self->req->headers->host ~~ ['api.sfsw.ru','api.evekill.info', 'localhost:3000', '172.17.0.3:3000'] ) {

            return $self->reply->not_found;
        }

        my $path = $self->{tx}->{req}->{url}->{path}->{path};
        my $user = ApiChecker::Core::User->new( $self->stash('db') );
        # Authenticated
        if ( $user->load_user( $self->session('id') ) ) {
            unless ( $path ~~ ['/','/logout/'] ) {
                unless ( $user->check_roles( $self ) ) {
                        $self->session( errors => [{text => 'Правов таких не имеете', type => 'danger'}] );
                        $self->redirect_to('/');
                        return undef;
                }
            }
            return 1;
        }

        # Not authenticated
        $self->redirect_to('/login');
        return undef;
    });


    $r->any('/add_api')->to('main#add_api');

	# Normal route to controller
    $r->any('/login')->to('main#login');

    # Files
    $r->any('/files/')->to('files#index');
    $r->any('/files/show/:file_id')->to('files#show');
    $auth->any('/files/admin')->to('files#admin');
    $auth->any('/files/admin/show/:file_id')->to('files#admin_show');

    $auth->any('/ts3')->to('ts3#index');
    $auth->post('/ts3/ips/:client_id')->to('ts3#ips');

    $auth->any('/forum')->to('forum#index');
    $auth->post('/forum/ips/:userid')->to('forum#ips');

    # Auth route
	$auth->any('/')->to('main#index');
	$auth->get('/logout')->to('main#logout');

    #Api route
    $auth->get('/api')->to('api#index');
    $auth->post('/api/add')->to('api#add');
    $auth->route('/api/delete/:id')->via('post')->to('api#delete')->name('id');
    $auth->route('/api/force/:id')->via('get')->to('api#force_update')->name('id');

    #Users route
    $auth->route('/users')->via(['post','get'])->to('users#index')->name('id');
    $auth->route('/users/delete/:id')->via('post')->to('users#delete')->name('id');
    $auth->route('/users/corps/:id/:corps')->via('post')->to('users#corps')->name('id');


    # Assets route
    $auth->route('/assets')->via('get')->to('assets#index')->name('id');

    # Starbase route
    $auth->route('/starbase')->via('get')->to('starbase#index')->name('id');
    $auth->route('/starbase/moons')->to('starbase#moons')->name('id');
    $auth->route('/starbase/find_moon')->via('post')->to('starbase#find_moon')->name('id');
    $auth->route('/starbase/edit_moon')->via('post')->to('starbase#edit_moon')->name('id');
    $auth->any('/starbase/del_moon')->to('starbase#del_moon');

    $auth->route('/industry')->via('get')->to('industry#index')->name('id');


    # Favorites route
    $auth->any('/favorites')->to('main#favorites');
    $auth->post('/favorites/add/:id')->to('main#favorites_add')->name('id');
    $auth->post('/favorites/del/:id')->to('main#favorites_del')->name('id');

    # Tags route
    $auth->any('/tags/change/:id/:tag')->to('main#tags_change');
    
    # Bigboy route
    $auth->any('/bigboys')->to('main#bigboys');
    $auth->any('/bigboys/change/:id/:value')->to('main#change_bigboy');


    #Character route
    #$auth->any('/character')->to('users#index');
    $auth->route('/character/:id')->via('get')->to('character#show')->name('id');
    $auth->route('/character/assets/:id')->via('get')->to('character#assets')->name('id');
    $auth->route('/character/assets_list/:id/:loc/:contents')->via('post')->to('character#assets_list')->name('id');

    $auth->route('/character/contacts/:id')->via('get')->to('character#contacts')->name('id');
    $auth->route('/character/contracts/:id')->via('get')->to('character#contracts')->name('id');
    $auth->route('/character/contracts/items/:char_id/:contract_id')->via('post')->to('character#contract_items')->name('id');
    $auth->route('/character/journal/:id')->via('get')->to('character#journal')->name('id');
    $auth->route('/character/transactions/:id')->via('get')->to('character#transactions')->name('id');
    $auth->route('/character/mails/:id')->via('get')->to('character#mails')->name('id');
    $auth->route('/character/log/:id')->via('get')->to('character#log')->name('id');

    #Contracts route
    $auth->any('/contracts')->to('contracts#index');
}

1;
