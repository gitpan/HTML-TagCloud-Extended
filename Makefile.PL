use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'HTML::TagCloud::Extended',
    VERSION_FROM      => 'lib/HTML/TagCloud/Extended.pm', # finds $VERSION
    PREREQ_PM         => {
		HTML::TagCloud	=> 0,
		Time::Local		=> 0,
	},
);
