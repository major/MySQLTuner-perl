package MySQLTuner::IssueTriageBridge;

use strict;
use warnings;
use JSON::PP ();

our $VERSION = '1.0.0';

sub new {
    my ($class, %args) = @_;
    my $self = {
        json => JSON::PP->new->utf8->canonical->pretty,
        maintainer_username => $args{maintainer} // 'jmrenouard',
    };
    return bless $self, $class;
}

sub classify_author {
    my ($self, $username) = @_;
    return 'unknown' unless defined $username;
    
    $username = lc($username);
    $username =~ s/^\s+|\s+$//g;
    
    if ($username eq lc($self->{maintainer_username})) {
        return 'maintainer';
    }
    if ($username =~ /^(?:dependabot(?:\[bot\])?|coderabbit(?:\[bot\])?|github-actions(?:\[bot\])?)$/) {
        return 'bot';
    }
    return 'community';
}

sub parse_version_string {
    my ($self, $version_raw) = @_;
    return { major => 0, minor => 0, patch => 0, engine => 'Unknown', normalized => '0.0.0' } unless defined $version_raw;
    
    my $is_mariadb = 0;
    my ($major, $minor, $patch) = (0, 0, 0);
    
    if ($version_raw =~ /^5\.5\.5-(\d+)\.(\d+)\.(\d+)(?:-.*)?-MariaDB/i) {
        $is_mariadb = 1;
        ($major, $minor, $patch) = ($1, $2, $3);
    } elsif ($version_raw =~ /MariaDB/i) {
        $is_mariadb = 1;
        if ($version_raw =~ /(\d+)\.(\d+)\.(\d+)/) {
            ($major, $minor, $patch) = ($1, $2, $3);
        }
    } elsif ($version_raw =~ /(\d+)\.(\d+)\.(\d+)/) {
        ($major, $minor, $patch) = ($1, $2, $3);
    }
    
    my $engine = $is_mariadb ? 'MariaDB' : 'MySQL';
    my $normalized = "$major.$minor.$patch";
    
    return {
        raw => $version_raw,
        major => int($major),
        minor => int($minor),
        patch => int($patch),
        engine => $engine,
        normalized => $normalized,
        is_mariadb => $is_mariadb ? 1 : 0,
    };
}

sub extract_system_variables {
    my ($self, $text) = @_;
    return {} unless defined $text;
    
    my %vars;
    # Matches patterns like: innodb_buffer_pool_size = 1073741824 or table_open_cache: 4000
    while ($text =~ /^\s*([a-zA-Z0-9_]{3,64})\s*[:=]\s*([^\s#;]+)/gm) {
        my ($var_name, $var_value) = ($1, $2);
        $var_name = lc($var_name);
        $var_value =~ s/^['"]|['"]$//g;
        $vars{$var_name} = $var_value;
    }
    return \%vars;
}

sub validate_issue_hash {
    my ($self, $issue_ref) = @_;
    my @errors;
    
    for my $field (qw/number title author state body/) {
        if (!defined $issue_ref->{$field} || $issue_ref->{$field} eq '') {
            push @errors, "Missing required field: $field";
        }
    }
    
    if (defined $issue_ref->{number} && $issue_ref->{number} !~ /^\d+$/) {
        push @errors, "Field 'number' must be a positive integer";
    }
    
    return (scalar(@errors) == 0 ? 1 : 0, \@errors);
}

sub encode_json {
    my ($self, $data_ref) = @_;
    return $self->{json}->encode($data_ref);
}

sub decode_json {
    my ($self, $json_str) = @_;
    return $self->{json}->decode($json_str);
}

1;
