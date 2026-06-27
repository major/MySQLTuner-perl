#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

my $project_root = abs_path(File::Spec->catfile(dirname(abs_path(__FILE__)), '..'));
my $agent_dir = File::Spec->catfile($project_root, '.agent');
my $readme_path = File::Spec->catfile($agent_dir, 'README.md');

sub parse_markdown_metadata {
    my ($file_path) = @_;
    open my $fh, '<', $file_path or return (basename($file_path), "Error: $!");
    my $content = do { local $/; <$fh> };
    close $fh;

    my $title = basename($file_path);
    if ($content =~ /^#\s+(.*)/m) {
        $title = $1;
        $title =~ s/^\s+|\s+$//g;
    }

    my $description = "No description available.";
    if ($content =~ /description:\s*(.*)/) {
        $description = $1;
        $description =~ s/^\s+|\s+$//g;
    }

    return ($title, $description);
}

sub generate_readme {
    my %categories = (
        'rules'     => 'Governance & Execution Constraints',
        'skills'    => 'Specialized Capabilities & Knowledge',
        'workflows' => 'Automation & Operational Workflows'
    );

    # Keep a fixed iteration order for predictability: rules -> skills -> workflows
    my @cat_order = ('rules', 'skills', 'workflows');

    my @output;
    push @output, "# .agent - Project Governance & Artificial Intelligence Intelligence\n";
    push @output, "This directory contains the project's technical constitution, specialized skills, and operational workflows used by AI agents.\n";

    for my $folder (@cat_order) {
        my $cat_title = $categories{$folder};
        my $folder_path = File::Spec->catdir($agent_dir, $folder);
        next unless -d $folder_path;

        push @output, "## $cat_title\n";
        push @output, "| File | Description |";
        push @output, "| :--- | :--- |";

        opendir(my $dh, $folder_path) or die "Cannot open $folder_path: $!";
        my @files = sort grep { $_ ne '.' && $_ ne '..' } readdir($dh);
        closedir($dh);

        for my $filename (@files) {
            my $full_path = File::Spec->catfile($folder_path, $filename);
            if (! -f $full_path) {
                # Handle skill folders containing SKILL.md
                my $skill_path = File::Spec->catfile($folder_path, $filename, 'SKILL.md');
                if (-f $skill_path) {
                    my (undef, $desc) = parse_markdown_metadata($skill_path);
                    push @output, "| [`$filename/`](./$folder/$filename/SKILL.md) | $desc |";
                }
                next;
            }
            next unless $filename =~ /\.md$/;

            my (undef, $desc) = parse_markdown_metadata($full_path);
            push @output, "| [`$filename`](./$folder/$filename) | $desc |";
        }

        push @output, "\n";
    }

    push @output, "---\n*Generated automatically by `/doc-sync`*";

    open my $fh, '>', $readme_path or die "Cannot write to $readme_path: $!";
    print $fh join("\n", @output);
    close $fh;

    print "Documentation synchronized: $readme_path\n";
}

generate_readme();
exit 0;
