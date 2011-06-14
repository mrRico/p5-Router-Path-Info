package Router::PathInfo::Static;
use strict;
use warnings;

use namespace::autoclean;
use Carp;
use Plack::MIME;
use File::Spec;
use File::MimeInfo::Magic;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

=head1 NAME

Router::PathInfo::Static

=head1 DESCRIPTION

Класс для описания роутинга статики.
Позволяет описать статику в следующем виде:

- указать стартовый сегмент URI

- указать директорию на диске. где будет проходить поиск статики

Статика здесь разделяется на две части:

- allready - уже существующая ("классическая") статика

- on_demand - создаваемая по требованию

Если случай C<allready> - это различные css, js, картинки, то C<on_demand> - это архивы и прочее.
Если файл для C<on_demand> не найден, C<match> вернёт undef - сигнал к тому, что поиск имеет смысл продолжить среди роутинга по правилам.  

В случае успеха возвращает L<Router::PathInfo::Match::Static> или L<Router::PathInfo::Match::Error> в случае ошибки.
Возврат C<undef> означает, что имеет смысл продолжить поиск совпадения URI на контроллеры.  

=head1 SYNOPSIS
    
    my $static_dispatch = Router::PathInfo::Static->new(
        # describe simple static 
        allready => {
            path => '/path/to/static',
            first_uri_segment => 's'
        },
        
        # describe on demand created static
        on_demand => {
            path => '/path/to/cached',
            first_uri_segment => 'cached',
        }
    );
    
    # dispath example:
    # http://example.org/s/css/main/some.file     => /path/to/static/css/main/some.file
    # http://example.org/css/main/foo/some.file   => 404 # need 's' as first uri segnemt
    
    # http://example.org/cached/archive/1254.html => /path/to/cached/archive/1254.html or undef
    
    # http://example.org/s/css/main/some.file~    => 403 (no ~ in file name)
    # http://example.org/s/css/main/.some.file    => 403 (file starts with .)
    
    my $ret = $static_dispatch->match( URI->new('http://example.org/s/css/slave/some.jpg') );
    
    # Dumper($ret) if /path/to/static/css/slave/some.jpg exists, have length, and readable:
    #    {
    #      'mime_type' => 'image/jpeg',
    #      'file_name' => '/path/to/static/css/slave/some.jpg',
    #    };

=head1 METHODS

=head2 new(allready => {path => $dir, first_uri_segment => $uri_segment}, on_demand => {...})

Конструктор, принимает описания обычной статики (allready) и/или статики создаваемой по требованию (on_demand).
Каждое описание представляет из себя hashref с ключами path (путь к директории) 
и first_uri_segment (первый сегмент URI, который определяет неймспейс выдленный для обозначенных нужд).    

=cut
sub new {
	my $class = shift;
	my %param = @_;
	
	my $hash = {};
	
	for (qw(allready on_demand)) {
		my $token = delete $param{$_};
		if (ref $token) {
	        if (-e $token->{path} and -d _ and $token->{first_uri_segment}) {
	            $hash->{$_.'_path'}        = $token->{path};
	            $hash->{$_.'_uri_segment'} = $token->{first_uri_segment};
	            $hash->{$_}                = 1;
	        } else {
	            $hash->{$_}                = 0;
	        }
		}
	}
	$hash->{md5} = md5_hex(Dumper($hash)); 
	return keys %$hash ? bless($hash, $class) : undef;
}

sub _rules_md5 {shift->{md5}}

sub _type_uri {
    my $self          = shift;
    my $first_segment = shift;
    
    for (qw(allready on_demand)) {
    	return $_ if ($self->{$_} and $first_segment eq $self->{$_.'_uri_segment'});
    }
    
    return;
}

=head2 match($uri)

Objects method. 
Receives a uri and return:

- L<Router::PathInfo::Match::Static> instance if file exists

- L<Router::PathInfo::Match::Error> instance, something error

- undef, need continue to research

For C<on_demand> created static, return undef if file not found.
L<Router::PathInfo::Match::Static> provide what file file exists, have length, and readable.

=cut
sub match {
    my $self = shift;
    my $env  = shift;
        
    my @segment = @{$env->{'psgix.RouterPathInfo'}->{segments}};

    my $serch_file = pop @segment;
    return unless ($serch_file and @segment);
    
    # проверим первый сегмент uri на принадлежность к статике
    my $type = $self->_type_uri(shift @segment);
    return unless $type;

    # среди прочего небольшая защита для никсойдов, дабы не отдать секьюрные файлы
    return {
        type  => 'error',
        value => [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['Forbidden']],
        desc  => sprintf('forbidden for PATH_INFO = %s', $env->{PATH_INFO})   
    } if ($serch_file =~ /^\./ or $serch_file =~ /~/ or grep {$_ =~ /^\./ or $_ =~ /~/} @segment);

    $serch_file = File::Spec->catfile($self->{$type.'_path'}, @segment, $serch_file);
    if (-f $serch_file and -s _ and -r _) {
        return {
            type  => 'static',
            file  => $serch_file,
            mime  => Plack::MIME->mime_type($serch_file) || mimetype($serch_file)
        }
    } else {
        return $type eq 'allready' ?
            {
                type  => 'error',
                value => [404, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['Not found']],
                desc  => sprintf('not found static for PATH_INFO = %s', $env->{PATH_INFO})
            } : 
            undef;
    }
}

=head1 DEPENDENCIES

L<File::MimeInfo::Magic>

=head1 AUTHOR

mr.Rico <catamoose at yandex.ru>

=cut
1;
__END__
