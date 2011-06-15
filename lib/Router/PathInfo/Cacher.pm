package Router::PathInfo::Cacher;

use strict;
use warnings;

use namespace::autoclean;
use Carp;
use Scalar::Util qw(blessed);
use Digest::MD5 qw(md5_hex);

@Router::PathInfo::Cacher::interface = qw(get set namespace);

# если скинуть значение в 0, то кеширования происходить не будет
# для ошибок кеширование настраивается на основе Router::PathInfo::Match::Error->code, т.к.
# 500-ю кешировать нет смысла, а вот 404 - возможно...
$Router::PathInfo::Cacher::ttl_match = {
    'static'        => 10*60,
    'controller'    => 5*60,
    '404'           => 0
};

sub new {
    my $class = shift;
    
    my %param = @_;
    
    # проверка memcache
    unless (blessed($param{cacher})) {
        carp "argument must be cacher instance";
        return;
    }

    for (@Router::PathInfo::Cacher::interface) {
        unless ($param{cacher}->can($_)) {
            carp blessed($param{cacher})." not implemented interface with ".join(',', map {"'$_'"} @Router::PathInfo::Cacher::interface);
            return;
        };
    } 
    
    # создаём объект
    my $self = bless {
        cacher         => $param{cacher},
        ns_prefix      => $param{ns_prefix} || ''
    }, $class;
    
    return $self;
}

sub namespace {$_[0]->{cacher}->namespace($_[0]->{ns_prefix}.':'.$_[1].':')}

=head2 get($uri, $http_method)

Метод, проверяет а базе наличие успешного совпадения для path от uri по соотвествующемц методу

=cut
sub match {
    my ($self, $env) = @_;
    return $self->{cacher}->get($self->_make_key($env));
}

sub _make_key {
    my $self = shift;
    my $env  = shift;
    return md5_hex(join('', $env->{PATH_INFO}, $env->{REQUEST_METHOD}));
}

sub set_match {
    my ($self, $env, $result) = @_;
    
    my $ttl_key = $result->{type} eq 'error' ? $result->{code} : $result->{type}; 
    
    my $ttl = exists $Router::PathInfo::Cacher::ttl_match->{$ttl_key} ? 
                                $Router::PathInfo::Cacher::ttl_match->{$ttl_key} : 
                                $Router::PathInfo::Cacher::ttl_match->{'404'}; 
    
    # если не задано ttl для кеширования - кеширование match'ей не выполняем
    return $ttl ? $self->{cacher}->set($self->_make_key($env), $result, $ttl) : 1;
}

=head1 AUTHOR

mr.Rico <catamoose at yandex.ru>

=cut
1;
__END__
