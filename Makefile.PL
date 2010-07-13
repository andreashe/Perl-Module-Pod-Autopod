# -*- mode: perl; c-basic-offset: 10; indent-tabs-mode: nil; -*-
use 5.006; #Pod::Abstract
use ExtUtils::MakeMaker;
WriteMakefile1(
          LICENSE => 'lgpl',
          MIN_PERL_VERSION => '5.006',
          META_MERGE => {
                    resources => {
                              repository => 'http://github.com/andreashe/Pod-Autopod',
                    },
          },
          BUILD_REQUIRES => {
                              'Test::More' => 0,
          },
          'NAME' => 'Pod::Autopod',
          'VERSION_FROM' => 'lib/Pod/Autopod.pm',
          'PREREQ_PM' => {
                           'FileHandle' => 0,
                           'strict' => 0,
                           'Pod::Abstract' => 0,
                           'Pod::Abstract::BuildNode' => 0,
                           'Getopt::Long' => 0,
                           'Pod::Text' => 0,
                         },
          'INSTALLDIRS' => 'site',
          'EXE_FILES' => ['bin/autopod'],
          'PL_FILES' => {},
          'AUTHOR'   => 'Andreas Hernitscheck <ahernit@cpan.org>', 
);



sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
          my %params=@_;
          my $eumm_version=$ExtUtils::MakeMaker::VERSION;
          $eumm_version=eval $eumm_version;
          die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
          die "License not specified" if not exists $params{LICENSE};
          if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
                    #EUMM 6.5502 has problems with BUILD_REQUIRES
                    $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
                    delete $params{BUILD_REQUIRES};
          }
          delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
          delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
          delete $params{META_MERGE} if $eumm_version < 6.46;
          delete $params{META_ADD} if $eumm_version < 6.46;
          delete $params{LICENSE} if $eumm_version < 6.31;
          delete $params{AUTHOR} if $] < 5.005;
          delete $params{ABSTRACT_FROM} if $] < 5.005;
          delete $params{BINARY_LOCATION} if $] < 5.005;

          WriteMakefile(%params);
}

