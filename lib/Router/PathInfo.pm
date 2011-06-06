package Router::PathInfo;
use strict;
use warnings;

our $VERSION = '0.01';

use namespace::autoclean;
use Carp;
use Digest::MD5 qw(md5_hex);

use Router::PathInfo::Controller;
use Router::PathInfo::Static;
use Router::PathInfo::Cacher;

=head1 NAME

Router::PathInfo

=head1 DESCRIPTION

Позволяет балансировать входящие url на статику и контроллеры.
Обладает простым и понятным интерфейсом.
Обуспечивает свзяь C<url - match> как C<один-к-одному>. 

Для поиска совпадений на контроллеры использует дерево,
выбор ветки в котором определяется весом правила, http-методом доступа и числом успешных совпадений за определённый промежуток времени.

Статика делится на 2 части: стандартная и создаваемая по требованию.
Если в предопределённой папке не была найдена статика создаваемая по требованию, 
то поиск продолжается по дереву правил до нахождения подходящего контроллера.

Предусмотрена возможность расширять набор правил для описаний uri собтвенными правилами.

В ответ вы всегда получаете объект совпадения. Один из трёх возможных:

- cовпадение по статике L<Router::PathInfo::Match::Static>

- cовпадение по контроллерам L<Router::PathInfo::Match::Rule>

- ошибка L<Router::PathInfo::Match::Error>

Вы можете передать объект mamcache и, тем самым избежать повторного вычиления для одного и того же uri.
Есть возможность задавать время кеширования для каждого типа совпадения.

И, конечно, предусмотрена загрузка правил как из файла (в формате L<Config::Tiny>), так и через интерфейс.

=head1 SYNOPSIS

    use Router::PathInfo;
    
    # or
    use Router::PathInfo as => singletone;
    # this allow to call after new: instance, clear_singleton
    
    my $router = Router::PathInfo->new(
        static => ...,
        controller => {
            rules_file => '/path/to/rule.ini'
        }
    );
    
    $router->controller->add_rule(
        connect => '/foo/:int/bar',
        controller => 'My::Class',
        action => 'some_method',
        method => 'POST'
    );
    
    my $match = $router->match('http://example.com/foo/200/bar');
    # or 
    my $match = $router->match('/foo/200/bar');
    

=head1 PACKAGE VARIABLES

=head2 $Router::PathInfo::as_singleton

Режим работы как singletone. По умолчанию - 0.
Можно поднять впрямую, или:

    use Router::PathInfo as => singletone;
    # or
    require Router::PathInfo;
    Router::PathInfo->import(as => singletone);
    # or
    $Router::PathInfo::as_singleton = 1
    
Если вы решаете работать в singletone режиме, поднимите флаг до вызова new. 

=cut

my $as_singletone = 0;

sub import {
    my ($class, %param) = @_;
    $as_singletone = 1 if ($param{as} and $param{as} eq 'singletone');
    return;
}

=head1 CLASS METHODS

=head2 new(static => $static, memcached => $memcached, controller => $controller)

Конструктор. Все аргументы опциоанльны.

static     - это hasref аргументов для конструктора L<Router::PathInfo::Static>
memcached  - объект с мемкеш-интерфейсом (подробнее см L<Router::PathInfo::Cacher>)
controller - это hasref аргументов для конструктора L<Router::PathInfo::Controller>

=cut

my $singleton = undef;

sub new {
    return $singleton if ($as_singletone and $singleton);
    
    my $class = shift;
    if (@_ % 2) {
        carp "wrong passed arguments";
        return;
    }
    my $param = {@_};
    
    my $self = bless {
        static      => UNIVERSAL::isa($param->{static}, 'HASH') ? Router::PathInfo::Static->new(%{delete $param->{static}}) : undef,
        controller  => UNIVERSAL::isa($param->{controller}, 'HASH') ? Router::PathInfo::Controller->new(%{delete $param->{controller}}) : Router::PathInfo::Controller->new(),
        cacher      => undef
    }, $class;
    
    if ($param->{cacher}) {
        $self->{cacher} =  Router::PathInfo::Cacher->new(cacher => $param->{cacher}, namespace => $self->_rules_md5);
    };
    
    $singleton = $self if $as_singletone;
     
    return $self;
}

sub _rules_md5 {
	my $self = shift;
	my $str = $self->{controller}->_rules_md5;
	$str .= $self->{static}->_rules_md5 if $self->{static};
	
	return md5_hex($str);
}


=head1 SINGLETON

Когда Вы работает в режиме синглетона, вам доступны методы: C<instance> и C<clear_singleton>

=cut
sub instance        {$as_singletone ? $singleton : carp "singletone not allowed"}
sub clear_singleton {undef $singleton}

=head1 OBJECT METHODS

=head1 cacher

Доступ к объекту кеширования L<Router::PathInfo::Cacher>

=head1 static

Доступ к объекту роутинга статики L<Router::PathInfo::Static>

=head1 controller

Доступ к объекту роутинга контроллеров L<Router::PathInfo::Controller>

=cut
#sub cacher          {shift->{cacher}}
#sub static          {shift->{static}}
#sub controller      {shift->{controller}}

=head2 match($url[, $method])

Поиск совпадения. Вначале проверяется наличие совпадения в кеше, затем по статике, и по правилам среди контроллеров.

Совпадение по статике - L<Router::PathInfo::Match::Static>.

Совпадение по контроллерам - L<Router::PathInfo::Match::Rule>.

Не найдено - L<Router::PathInfo::Match::Error>.

=cut
sub match {
    my $self = shift; 
    my $url  = shift;
    my $method  = shift;
    
    # job with URI object only
    my $uri = UNVERSAL::isa($url,'URI') ? $url : URI->new($url);
    
    # clear uri inside: /foo///bar/ -> /foo/bar/
    my @segment = $uri->path_segments;
    my $root = shift @segment;
    my $last_segment = pop @segment;
    @segment = grep {length $_} @segment;
    unless (@segment) {
        @segment = $root; 
    } else {
        unshift @segment, $root; 
        push @segment, $last_segment if defined $last_segment;
    }
    $uri->path_segments(@segment);
    
    my $match = undef;
    
    # set defult http method - GET
    $method ||= 'GET';
    # uppercase http method
    $method = uc $method;
    # check method
    unless (Router::PathInfo::Base::Rule->allow_http_methods->{$method}) {
        $match = Router::PathInfo::Match::Error->new(code => 405, message => "Method Not Allowed");
    }
    
    # check in cache
    if (not $match and $self->cacher) {
        $match = $self->cacher->match($uri, $method);
        if ($match and not UNIVERSAL::isa($match, 'Router::PathInfo::Match::Error')) {
            $self->controller->_incr($match->{_meta}) if ref $match->{_meta};
        };
    };
    
    # check in static
    if (not $match and $self->static) {
        $match = $self->static->match($uri);
    }
    
    # check in controllers
    if (not $match and $self->controller) {
        $match = $self->controller->match($uri, $method);
        if ($match and not UNIVERSAL::isa($match, 'Router::PathInfo::Match::Error')) {
            $self->controller->_incr($match->{_meta}) if ref $match->{_meta};
        };
    }    
    
    # not found?
    $match ||= Router::PathInfo::Match::Error->new(code => 404, message => "Not found");
    
    # set in cache
    $self->cacher->set_match($uri, $method, $match) if $self->cacher;
    
    # match is done
    return $match;
}

=head1 NOTE

Для C<Router::PathInfo> не имеет значения в каком порядке вы загружаете правила. Использование дерева (а не массива регулярных выражений) гарантирует,
что каждое описание url и контроллера найдёт своё место.

Существует общая проблема роутинга, которую можно описать так:

    1) /:any/baz -> POST
    2) /foo/:any -> all http methods
    
    http://example.com/foo/baz with POST 
    1 or 2
    ?

C<Router::PathInfo> разрешает эту проблему отдавая предпочтение варианту C<2)>, 
так как до перехода к C<1)> мы должны исключить совпадение foo с C<:any>.   

Вес сегмента ури доминирует над методом доступа при поиске совпадения.

Если Вы используете C<REST> иделогию, Вам нужно позаботиться о точности описания вышестоящих сегментов uri и, отдавать предпочтение
правилам с наименьшим весом (высокая точность). Подробнее о весах правил можно посмотреть C<Router::PathInfo::Rule::*>.

=head1 SEE ALSO

L<Router::PathInfo::Static>, L<Router::PathInfo::Controller>, L<Router::PathInfo::Cacher>

=head1 AUTHOR

mr.Rico <catamoose at yandex.ru>

=cut
1;
__END__
