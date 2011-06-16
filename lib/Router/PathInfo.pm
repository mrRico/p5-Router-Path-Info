package Router::PathInfo;
use strict;
use warnings;

our $VERSION = '0.01';

use namespace::autoclean;
use Carp;

use Router::PathInfo::Controller;
use Router::PathInfo::Static;

=head1 NAME

B<Router::PathInfo> - PATH_INFO router, based on search trees

=head1 DESCRIPTION

Allows balancing PATH_INFO to static and controllers.
It has a simple and intuitive interface.

=head1 SYNOPSIS

    use Router::PathInfo;
    
    # or
    use Router::PathInfo as => singletone;
    # this allow to call after new: instance, clear_singleton
    
    my $r = Router::PathInfo->new( 
        static => {
            allready => {
                path => '/path/to/static',
                first_uri_segment => 'static'
            }
        }
    );
        
    $r->add_rule(
        connect         => '/foo/:enum(bar|baz)/:re(^\d{4}$)/:any', 
        action          => $some_thing,
        mthods          => ['GET','DELETE'],
        match_callback  => $code_ref
    );
    
    my $env = {PATH_INFO => '/foo/bar/2011/baz', REQUEST_METHOD => 'GET'};
    
    my $res = $r->match($env);
    # or
    my $res = $r->match('/foo/bar/2011/baz'); # GET by default
    
    # $res = {
    #     type => 'controller',
    #     action => $some, # result call $code_ref->($match, $env)
    #     segment => ['bar','2011','baz']
    # }
    
    $env = {PATH_INFO => '/static/img/some.jpg'};
    
    $res = $r->match($env);
    
    # $res = {
    #     type  => 'static',
    #     file  => '/path/to/static/img/some.jpg',
    #     mime  => 'image/jpeg'
    # }    

See more details L<Router::PathInfo::Controller>, L<Router::PathInfo::Static>

=head1 PACKAGE VARIABLES

=head2 $Router::PathInfo::as_singleton

Mode as singletone. By default - 0.
You can pick up directly, or:

    use Router::PathInfo as => singletone;
    # or
    require Router::PathInfo;
    Router::PathInfo->import(as => singletone);
    # or
    $Router::PathInfo::as_singleton = 1
    
If you decide to work in singletone mode, raise the flag before the call to C<new>. 

=cut

my $as_singletone = 0;

sub import {
    my ($class, %param) = @_;
    $as_singletone = 1 if ($param{as} and $param{as} eq 'singletone');
    return;
}

=head1 SINGLETON

When you work in a mode singletone, you have access to methods: C<instance> and C<clear_singleton>

=cut


=head1 METHODS

=head2 new(static => $static)

Constructor. All arguments optsioanlny.

static - it hashref arguments for the constructor L<Router::PathInfo::Static>

=cut

my $singleton = undef;

sub new {
    return $singleton if ($as_singletone and $singleton);
    
    my $class = shift;
    my $param = {@_};
    
    my $self = bless {
        static      => UNIVERSAL::isa($param->{static}, 'HASH')     ? Router::PathInfo::Static->new(%{delete $param->{static}}) : undef,
        controller  => UNIVERSAL::isa($param->{controller}, 'HASH') ? Router::PathInfo::Controller->new(%{delete $param->{controller}}) : Router::PathInfo::Controller->new()
    }, $class;
    
    $singleton = $self if $as_singletone;
     
    return $self;
}

=head2 add_rule

See C<add_rule> from L<Router::PathInfo::Controller>

=cut
sub add_rule {
    my $self = shift;
    my $ret = 0;
    if ($self->{controller}) {
        $self->{controller}->add_rule(@_);
    } else {
        carp "controller not defined";
    }
}

sub instance        {$as_singletone ? $singleton : carp "singletone not allowed"}
sub clear_singleton {undef $singleton}

=head2 match({PATH_INFO => $path_info, REQUEST_METHOD => 'GET'})

Search match. Initially checked for matches on static, then according to the rules of the controllers.
In any event returns hashref coincidence or an error.

Example:

    {
      type  => 'error',
      code => 400,
      desc  => '$env->{PATH_INFO} not defined'  
    }
    
    {
      type  => 'error',
      code => 404,
      desc  => sprintf('not found for PATH_INFO = %s with REQUEST_METHOD = %s', $env->{PATH_INFO}, $env->{REQUEST_METHOD}) 
    }
    
    {
        type => 'controller',
        action => $action,
        segment => $array_ref_of_segments 
    }
    
    {
        type  => 'static',
        file  => $serch_file,
        mime  => $mime_type
    }

=cut
sub match {
    my $self = shift; 
    my $env  = shift;
    
    unless (ref $env) {
        $env = {PATH_INFO => $env, REQUEST_METHOD => 'GET'};
    } else {
        $env->{REQUEST_METHOD} ||= 'GET';
    }
    
    my $match = undef;
    
    $match = {
      type  => 'error',
      code => 400,
      desc  => '$env->{PATH_INFO} not defined'  
    } unless $env->{PATH_INFO};
    
    my @segment = split '/', $env->{PATH_INFO}, -1; shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    
    # check in static
    if (not $match and $self->{static}) {
        $match = $self->{static}->match($env);
    }
    
    # check in controllers
    if (not $match and $self->{controller}) {
        $match = $self->{controller}->match($env);
    }    
    
    # not found?
    $match ||= {
      type  => 'error',
      code => 404,
      desc  => sprintf('not found for PATH_INFO = %s with REQUEST_METHOD = %s', $env->{PATH_INFO}, $env->{REQUEST_METHOD}) 
    };
    
    delete $env->{'psgix.tmp.RouterPathInfo'};
    
    # match is done
    return $match;
}

=head1 SOURSE

git@github.com:mrRico/p5-Router-Path-Info.git

=head1 SEE ALSO

L<Router::PathInfo::Static>, L<Router::PathInfo::Controller>

=head1 AUTHOR

mr.Rico <catamoose at yandex.ru>

=cut
1;
__END__
