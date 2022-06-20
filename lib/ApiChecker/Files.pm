package ApiChecker::Files;
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
use ApiChecker::Core::Ts3;
use ApiChecker::Core::Forum;
use ApiChecker::Core::Utils qw( time_diff now );

sub index {
    my $self = shift;


    return $self->reply->not_found;
}

sub show {
    my $self = shift;

    my $file_id = $self->param('file_id');

    unless ($file_id) {
        return $self->reply->not_found;
    }

    my $files = ApiChecker::Core::Files->new( $self->stash('db') );

    my $file = $files->get_file( { hash => $file_id } );

    unless ($file) {
        return $self->reply->not_found;
    }

    $files->add_download({
        file => $file,
        ip   => $self->remote_addr,
        ua   => $self->req->headers->user_agent,
    });


    $self->render_file(
        'filepath' => $file->{path},
        'format'   => $file->{ext},                 # will change Content-Type "application/x-download" to "application/pdf"
        'content_disposition' => 'inline',   # will change Content-Disposition from "attachment" to "inline"
        #'cleanup'  => 1,                     # delete file after completed
    );

}


sub admin {
    my $self = shift;

    my $files = ApiChecker::Core::Files->new( $self->stash('db') );

    EXIT_IF: {
        if ( $self->req->method eq 'POST' && $self->req->upload('upload') ) {
            my $conf = YAML::Tiny->read( '/www/api_checker/config/conf.yaml' )->[0]->{file_uploads};

            my $upload = $self->req->upload('upload');

            my $norm_name = $files->normalize( $upload->filename );

            unless ( $norm_name ) {
                #push @errors, { text => 'Не корректное имя файла.', type => 'danger' };
                last EXIT_IF;
            } 

            my ( $ext, $name);
            if ( $norm_name =~ /^(.*)\.(.*)$/ ) {
                $ext  = lc $2;
                $name = lc $1;
            }

            unless ( $ext ~~ @{ $conf->{exts} } ) {
                #push @errors, { text => 'Недопустимое расширение файла', type => 'danger' };
                last EXIT_IF;
            }

            my $hash_name = $files->hash( $norm_name, $self->session('name') );

            my $data = {
                filename => $norm_name,
                size     => $upload->size,
                hash     => $hash_name,
                ext      => $ext,
                path     => $conf->{path} . $name . '_'. $hash_name,
                user     => $self->session('name'),
            };
            if ( _upload_file($self, $upload, $data) ) {
                #push @errors, { text => 'Файл загружен', type => 'success' };
            }
            else {
                #push @errors, { text => 'Файл не удалось загрузить', type => 'danger' };
            }

            $self->redirect_to('/files/admin' );
        }
    }

    my $page        = $self->param('page')  || 0;
       $page        = 0 if $page < 0;
    my $per_page    = $self->param('per_page') || 25;
    my $sort        = $self->param('sort');
    my $by          = $self->param('by')       || 'date';


    my $list = $files->get_files($page, $per_page, $by, $sort);

    my $page_count = $files->get_files_page_count( $page, $per_page );

    $self->render( header => 'Файлов админка', page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by, list_files => $list, hostname => $self->req->headers->host );
}


sub admin_show {
    my $self = shift;

    my $file_id = $self->param('file_id');

    unless ($file_id) {
        return $self->reply->not_found;
    }

    my $files = ApiChecker::Core::Files->new( $self->stash('db') );

    my $file = $files->get_file( { hash => $file_id } );

    unless ($file) {
        return $self->reply->not_found;
    }

    my $page        = $self->param('page')  || 0;
       $page        = 0 if $page < 0;
    my $per_page    = $self->param('per_page') || 100;
    my $sort        = $self->param('sort');
    my $by          = $self->param('by')       || 'date';

    my $list       = $files->get_downloads( $file->{id}, $page, $per_page, $by, $sort );
    my $page_count = $files->get_downloads_page_count( $file->{id}, $page, $per_page );

    my $ts3 = ApiChecker::Core::Ts3->new( $self->stash('db') );
    foreach my $row ( @$list ) {
        $row->{users} = $ts3->get_clients_by_ip( $row->{ip} );
    }

    my $forum = ApiChecker::Core::Forum->new( $self->stash('db') );
    foreach my $row ( @$list ) {
        $row->{forum} = $forum->get_clients_by_ip( $row->{ip} );
    }

    $self->render( header => 'Скачивания файла ' . $file->{filename}, page => $page, per_page => $per_page, page_count => $page_count, sort => $sort, by => $by, list_downloads => $list );
}

sub _upload_file {
    my ( $self, $upload, $data ) = @_;

    return if !$upload || !$data;

    unless ( $upload->move_to( $data->{path} ) ) {
        return;
    }

    my $files = ApiChecker::Core::Files->new( $self->stash('db') );

    unless ( $files->add_file( $data ) ) {
        return;
    }

    return 1;
}

1;
