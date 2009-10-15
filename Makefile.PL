use ExtUtils::MakeMaker;
WriteMakefile
(
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


