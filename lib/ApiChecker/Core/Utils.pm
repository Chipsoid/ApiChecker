package ApiChecker::Core::Utils;

use utf8;
use Modern::Perl;
use Data::Dumper;
use POSIX;
use Time::Piece;
use List::MoreUtils qw( any );

use Exporter;

use vars qw(@ISA @EXPORT);

@ISA=qw(Exporter);

our @EXPORT = ( qw(
    mydate2rus04 mydatetime2rus04 mysqldate_decode today_mydate now epoch2mydate time_diff subtract_set isin
) );

sub mydate2rus04 {
    my ( $date ) = @_;

    my ( $year, $month, $day ) = mysqldate_decode( $date );

    unless ( $year || $month || $day ) { return '-' };

    return sprintf "%02d.%02d.%04d", $day, $month, $year;
}

sub mydatetime2rus04 {
    my ( $date ) = @_;

    my $out_date = decode_date( $date, format => "%Y-%m-%d %H:%m:%s", out_format => "%d.%m.%Y %H:%m:%s" );
    return $out_date;
    # unless ( $year || $month || $day ) { return '-' };

    # return sprintf "%02d.%02d.%04d %02d:%02d:%02d", $day, $month, $year, $hour, $minute, $sec;
}

sub mysqldate_decode {
    my ( $date ) = @_;

    $date =~ s/\s.+$//x;

    if ( $date =~ /^(\d{4})-(\d{2})-(\d{2})/x ) {
        return ($1, $2, $3);
    }

    if ( $date =~ /^(\d{4})(\d{2})(\d{2})\d{6}$/x ) {
        return ($1, $2, $3);
    }

    return (0, 0, 0);
}

sub today_mydate {
    return epoch2mydate( time );
}

sub now {
    return epoch2mydate( time, 1 );
}

sub time_diff {
    my ( $dt1, $dt2 ) = @_;

    return if !defined $dt1 || !defined $dt2;

    $dt1 = decode_date( $dt1 );
    $dt2 = decode_date( $dt2 );

    return $dt2 - $dt1;
}

sub epoch2mydate {
    my ($time, $use_time_of_day) = @_;

    $time ||= time();

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = localtime( $time );

    my $result;
    if ( $use_time_of_day ) {
        $result = sprintf(
            "%04d-%02d-%02d %02d:%02d:%02d",
            $year+1900, $mon+1, $mday, $hour, $min, $sec
        );
    }
    else {
        $result = sprintf(
            "%04d-%02d-%02d",
            $year+1900, $mon+1, $mday
        );
    }

    return $result;
}

sub decode_date {
    my ( $date, %param ) = @_;

    return unless $date;

    my $format = $param{format};
    my $out_format = $param{out_format};
    my $islocal = exists $param{islocal} ? $param{islocal} : 1;

    if ( !$format ) {
        $format = $date =~ / \d{2}:\d{2}:\d{2}/ ? '%Y-%m-%d %T' : '%Y-%m-%d';
    }
    elsif ( $format eq 'mysql' ) {
        $format = '%Y-%m-%d';
    }

    if ( $format !~ /%T/x ) {
        $islocal = 0;
    }

    my $t = new Time::Piece;

    $t->[Time::Piece::c_islocal] = $islocal ? 1 : 0;

    $t = eval { $t->strptime( $date, $format ); };

    if ( $@ ) {
        debug_log( "Can't parse date: ($date, $format)" ) if $SRS::Conf::DEBUG;
        return;
    }

    if ( $islocal ) {
        $t->[Time::Piece::c_epoch] -= get_tzoffset( $t );
    }

    if ( $out_format ) {
        if ( $out_format eq 'mysql' ) {
            $out_format = '%Y-%m-%d';
        }

        return $t->strftime( $out_format );
    }
    else {
        return $t;
    }
}

sub get_tzoffset {
    my ( $t ) = @_;

    $t ||= Time::Piece->new;
    $t->[Time::Piece::c_islocal] = 1;

    return $t->tzoffset->seconds;
}

sub format_sum {
    my ( $sum, %params ) = @_;

    return '0.00'  unless $sum;
    my $rounded = $params{use_roundup} ? roundup($sum) : sprintf('%.2f', $sum);
    return sp2nbsp( format_number_triads( $rounded ) );
}

sub format_number_triads {
    my ( $number, $separator ) = @_;

    $separator = ' '  unless defined $separator;

    $number = reverse $number;
    $number =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1$separator/g;

    return scalar(reverse($number));
}

sub sp2nbsp {
    my ( $text ) = @_;

    $text =~ s/ /&nbsp;/g;

    return $text;
}

sub roundup {
    my ( $x,  $sharpness ) = @_;

    return unless defined $x;

    $sharpness ||= 0;
    my $coef;

    if ( $sharpness < 0 ) {
        $coef = 0.1;
        $sharpness = -$sharpness;
    }
    else {
        $coef = 10;
    }

    for ( my $i = 0; $i < $sharpness; $i++ ) {
        $x *= $coef;
    }

    $x = ceil( $x );

    for ( my $i = 0; $i < $sharpness; $i++ ) {
        $x /= $coef;
    }

    return $x;
}

sub subtract_set {
    my ( $s1_ref, $s2_ref ) = @_;

    return grep { !isin($_, $s2_ref) } @{ $s1_ref };
}


sub isin {
    my ( $val, $array_ref ) = @_;

    return ''  unless $array_ref && defined $val;

    return ( any { defined($_) && $_ eq $val } @{$array_ref} ) ? 1 : 0;
}


1;