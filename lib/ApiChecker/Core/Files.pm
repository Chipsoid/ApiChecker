package ApiChecker::Core::Files;

use utf8;
use Modern::Perl;
use POSIX;
use Data::Dumper;
use YAML::Tiny;
use Log::Log4perl;
use Digest::SHA qw( sha1_hex );

use ApiChecker::Core::Ts3;

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };

Log::Log4perl->init($config);
my $log = Log::Log4perl->get_logger('files');

sub new {
    my $class = shift;
    my $db = shift;
    $class = ref ($class) || $class;

    my $self;
    $self = {
        db => $db,
    };

    bless $self, $class;
    return $self;
}

sub normalize {
    my ( $self, $filename ) = @_;

    return unless $filename;

    $filename =~ s{\s+|\t+}{_};
    $filename =~ tr/а-яА-Я/a-yA-Y/;

    return $filename;
}


sub hash {
    my ( $self, $filename, $user ) = @_;

    return unless $filename;

    return sha1_hex( $filename . time() . $user );

}

sub add_file {
    my ( $self, $data ) = @_;

    return unless $data;

    $self->{db}->do("INSERT INTO files (`hash`, `filename`, `size`, `path`, `upload_date`, uploaded_by, `enabled`, `ext`) VALUES 
            (?, ?, ?, ?, NOW(), ?, ?, ?)", undef,
            $data->{hash},
            $data->{filename},
            $data->{size} || 0,
            $data->{path},
            $data->{user},
            1,
            $data->{ext},
        );

    return 1;
}

sub get_files {
    my ($self, $page, $per_page, $by, $order ) = @_;

    my $order_by = "ORDER BY f.upload_date DESC";
    if ( $by ~~ ['hash','filename', 'size', 'upload_date', 'uploaded_by'] ) {
        $order_by = "ORDER BY f.$by $order";
    }

    my $where = ' WHERE 1 = 1 ';
    my $join  = ' ';

    my $limit = " LIMIT ". ( $page * $per_page ) .", $per_page;";

    my $query = "SELECT f.*, ( SELECT COUNT(fd.file_id) FROM file_downloads fd WHERE fd.file_id = f.id ) as download_count
                FROM files f
                $where AND f.enabled = 1 $order_by $limit";
    return $self->{db}->selectall_arrayref($query, { Slice => {} }, ); 

}

sub get_file {
    my ($self, $params ) = @_;

    return unless $params->{hash};

    return $self->{db}->selectall_arrayref("SELECT * FROM files f WHERE hash = ? LIMIT 1", { Slice => {} }, $params->{hash} )->[0] || undef;
}

sub get_files_page_count {
    my ( $self, $page, $per_page ) = @_;

    my $query = "SELECT COUNT(f.id) FROM files f";

    my $records_count = $self->{db}->selectrow_array($query, undef);
    return ceil( $records_count / $per_page ); 
}

sub add_download {
    my ($self, $data) = @_;

    return unless $data;
 
    return $self->{db}->do("INSERT INTO file_downloads (file_id, `date`, `ip`, `who`, `ua`) VALUES (?, NOW(), ?, ?, ?)", undef,
        $data->{file}->{id},
        $data->{ip},
        $data->{who} || '',
        $data->{ua}
        );

}

sub get_downloads {
    my ( $self, $file_id, $page, $per_page, $by, $order ) = @_;

    $order ||= 'DESC';

    my $order_by = "ORDER BY f.date $order";
    if ( $by ~~ ['ua','ip', 'date', 'who'] ) {
        $order_by = "ORDER BY f.$by $order";
    }

    my $where = ' WHERE 1 = 1 ';
    my $join  = ' ';

    my $limit = " LIMIT ". ( $page * $per_page ) .", $per_page;";

    my $query = "SELECT * FROM file_downloads f  $where AND file_id = ?  $order_by $limit";

    my $list = $self->{db}->selectall_arrayref($query, { Slice => {} },, $file_id);
    return $list; 
}

sub get_downloads_page_count {
    my ( $self, $file_id, $page, $per_page ) = @_;

    my $query = "SELECT COUNT(f.id) FROM file_downloads f WHERE file_id = ?";

    my $records_count = $self->{db}->selectrow_array($query, undef, $file_id);
    return ceil( $records_count / $per_page ); 
}




1;