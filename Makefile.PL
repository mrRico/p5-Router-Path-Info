use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Router::PathInfo',
    VERSION_FROM      => 'lib/Router/PathInfo.pm',
    PREREQ_PM         => {
        'Carp'                  => 0,
        'Plack::MIME'           => 0,
        'File::Spec'            => 0,
        'File::MimeInfo::Magic' => 0
    },
    AUTHOR         => 'mr.Rico <catamoose@yandex.ru>',
);
