use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# Mock global variables
our %myvar;
our $cloud_type;
our $is_cloud;
our %result;

subtest 'mysql_cloud_discovery' => sub {
    # Case 1: AWS Aurora
    %main::myvar = (
        'version_comment' => 'MySQL Community Server (GPL) - Aurora 3.0.0',
        'aurora_version'  => '3.0.0'
    );
    is(main::mysql_cloud_discovery(), 'AWS Aurora', 'Detects AWS Aurora (version_comment)');
    is($main::cloud_type, 'AWS Aurora', 'Sets cloud_type to AWS Aurora');
    ok($main::is_cloud, 'Sets is_cloud to 1');

    # Case 2: AWS RDS
    %main::myvar = (
        'version_comment' => 'RDS MySQL Server',
        'basedir'         => '/rdsdbbin/mysql/'
    );
    is(main::mysql_cloud_discovery(), 'AWS RDS', 'Detects AWS RDS');

    # Case 3: GCP Cloud SQL
    %main::myvar = (
        'version_comment' => 'Google Cloud SQL',
        'socket'          => '/cloudsql/project:region:instance'
    );
    is(main::mysql_cloud_discovery(), 'GCP Cloud SQL', 'Detects GCP Cloud SQL');

    # Case 4: Azure Flexible Server
    %main::myvar = (
        'version_comment' => 'Azure MySQL Flexible Server',
        'azure.tenant_id' => 'some-uid'
    );
    is(main::mysql_cloud_discovery(), 'Azure Flexible Server', 'Detects Azure Flexible Server');

    # Case 5: Azure Managed (Single Server)
    %main::myvar = (
        'version_comment' => 'Azure MySQL Managed Server'
    );
    is(main::mysql_cloud_discovery(), 'Azure Managed MySQL', 'Detects Azure Managed MySQL');

    # Case 6: DigitalOcean
    %main::myvar = (
        'version_comment' => 'DigitalOcean Managed MySQL'
    );
    is(main::mysql_cloud_discovery(), 'DigitalOcean Managed MySQL', 'Detects DigitalOcean');

    # Case 7: None
    %main::myvar = (
        'version_comment' => 'MySQL Community Server (GPL)'
    );
    is(main::mysql_cloud_discovery(), 'none', 'Detects no cloud environment');
    ok(!$main::is_cloud, 'Sets is_cloud to 0');
};

done_testing();
