use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Circa::Search',
    'VERSION_FROM' => 'Search.pm', # finds $VERSION
    'PREREQ_PM'    => { 'DBI' => 0, 'DBD::mysql'=> 0 },
    'dist'=>
       {TARFLAGS => 'cvf', COMPRESS => 'gzip', SUFFIX => 'gz', DIST_CP => 'ln'}
    
);
