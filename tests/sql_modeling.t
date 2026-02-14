#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Load the script first to get the subroutines
{
    local @ARGV = (); # Empty ARGV for GetOptions
    no warnings 'redefine';
    require './mysqltuner.pl';
}

my @mock_output;
# Now mock the functions at runtime
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "MOCK INFO: $_[0]"; push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { diag "MOCK BAD: $_[0]"; push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { diag "MOCK GOOD: $_[0]"; push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { diag "MOCK DEBUG: $_[0]"; push @mock_output, "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "MOCK SUBHEADER: $_[0]"; push @mock_output, "SUBHEADER: $_[0]" };
    *main::dump_into_file = sub { diag "MOCK DUMP: $_[0]" };
    *main::hr_bytes = sub { return $_[0] };
    *main::select_user_dbs = sub { return ('test_db') };
}

# Mock select_array to handle multiple different queries
my %mock_queries;
my @mock_query_order; # For ordered matching if needed
{
    no warnings 'redefine';
    *main::select_array = sub {
        my ($query) = @_;
        diag "MOCK SELECT_ARRAY: $query";
        # Try finding a match in %mock_queries
        # Use more specific keys first? No, just keys.
        # Let's iterate through ordered patterns if we have them.
        foreach my $pattern (sort { length($b) <=> length($a) } keys %mock_queries) {
            if ($query =~ /$pattern/si) {
                diag "MOCK MATCHED: $pattern";
                return @{$mock_queries{$pattern}};
            }
        }
        diag "MOCK NO MATCH FOR: $query";
        return ();
    };
}

# Helper to find if a message exists in mock output
sub has_output {
    my ($pattern) = @_;
    return grep { $_ =~ /$pattern/ } @mock_output;
}

subtest 'Primary Key Checks (Baseline + Advanced)' => sub {
    %mock_queries = (
        'having sum\(if\(c.column_key in \(\'PRI\', \'UNI\'\), 1, 0\)\) = 0' => ['test_db,table_no_pk'],
        'COLUMN_KEY = \'PRI\'' => [
            "test_db\tusers\tid\tbigint\tbigint(20) unsigned auto_increment",      # Good PK
            "test_db\torders\tord_id\tint\tint(11) auto_increment",                # Bad PK name
            "test_db\tlogs\tlog_uuid\tvarchar\tvarchar(36) auto_increment",        # Non-optimized UUID
            "test_db\titems\tid\tint\tint(11)",                                    # Non-unsigned/auto_inc
        ],
        'ENGINE <> \'InnoDB\'' => [],
        'CHARacter_set_name  LIKE \'utf8%\'' => [],
        'data_type=\'FULLTEXT\'' => [],
        'SELECT TABLE_SCHEMA, TABLE_NAME, \(DATA_LENGTH \+ INDEX_LENGTH\).*1024\*1024\*1024' => [
            "test_db\tbig_table\t1073741825", # 1GB + 1 byte (tab separated)
        ],
        'statistics s WHERE s.TABLE_SCHEMA = t.TABLE_SCHEMA.*INDEX_NAME != \'PRIMARY\'' => [
           # Secondary indexes count = 0
        ],
    );
    @main::generalrec = ();
    %main::result = ();
    @mock_output = ();
    $main::opt{'structstat'} = 1;
    $main::opt{'nocolor'} = 1;
    # Set version for subroutines
    $main::myvar{'version'} = '8.0.30';
    
    diag "Calling mysql_table_structures with structstat=" . $main::opt{'structstat'};
    {
        no warnings 'redefine';
        local *main::mysql_naming_conventions = sub { };
        local *main::mysql_foreign_key_checks = sub { };
        local *main::mysql_80_modeling_checks = sub { };
        local *main::mysql_datatype_optimization = sub { };
        local *main::mysql_schema_sanitization = sub { };
        main::mysql_table_structures();
    }
    
    ok(grep { $_ =~ /test_db,table_no_pk/ } @{$main::result{'Tables without PK'}}, 'Table without PK detected');
    ok(has_output(qr/BAD: Table test_db.orders: Primary key 'ord_id' does not follow/), 'Bad PK name detected');
    ok(has_output(qr/BAD: Table test_db.logs: UUID primary key 'log_uuid' is not optimized/), 'Non-optimized UUID detected');
    ok(has_output(qr/BAD: Table test_db.items: Primary key 'id' is not a recommended surrogate key/), 'Non-unsigned/auto_inc PK detected');
    ok(has_output(qr/BAD: Table test_db.big_table is large \(1073741825\) and has no secondary indexes/), 'Large table without secondary indexes detected');
};

subtest 'Naming Convention Checks' => sub {
    $main::myvar{'version'} = '8.0.30';
    %mock_queries = (
        'tables.*TABLE_TYPE = \'BASE TABLE\'' => [
            "test_db\tusers",            # Plural (Bad)
            "test_db\torder_item",       # Snake + Singular (Good)
            "test_db\tOrderItem",        # camelCase (Bad)
        ],
        'columns.*TABLE_SCHEMA NOT IN' => [
            "test_db\torder_item\tis_active\ttinyint(1)",  # Good boolean
            "test_db\torder_item\tactive\ttinyint(1)",     # Bad boolean name
            "test_db\torder_item\tcreated\tdatetime",      # Bad date name
            "test_db\torder_item\tshipped_at\tdatetime",   # Good date name
            "test_db\torder_item\tUserName\tvarchar",      # camelCase column
        ],
    );
    @main::generalrec = ();
    @mock_output = ();
    
    main::mysql_naming_conventions();
    
    ok(has_output(qr/BAD: Table test_db.users: Plural name detected/), 'Plural table name detected');
    ok(has_output(qr/Table test_db.order_item: Plural name detected/) == 0, 'Singular table name ignored');
    ok(has_output(qr/BAD: Table test_db.OrderItem: Non-snake_case name detected/), 'camelCase table name detected');
    ok(has_output(qr/BAD: Column test_db.order_item.UserName: Non-snake_case name detected/), 'camelCase column name detected');
    ok(has_output(qr/INFO: Column test_db.order_item.active: Boolean-like column missing verbal prefix/), 'Missing boolean prefix detected');
    ok(has_output(qr/INFO: Column test_db.order_item.created: Date\/Time column missing explicit suffix/), 'Missing date suffix detected');
};

subtest 'Foreign Key Checks' => sub {
    $main::myvar{'version'} = '8.0.30';

    %mock_queries = (
        'COLUMN_NAME LIKE \'%_id\'.*COLUMN_NAME IS NULL' => [
            "test_db\torders\tpromo_id",
        ],
        'referential_constraints' => [
            "test_db\torders\tuser_id\tusers\tid\tCASCADE", # FK with CASCADE
        ],
    );
    @main::generalrec = ();
    @mock_output = ();
    
    main::mysql_foreign_key_checks();
    
    ok(has_output(qr/BAD: Column test_db.orders.promo_id ends in '_id' but has no FOREIGN KEY/), 'Unconstrained _id column detected');
    ok(has_output(qr/INFO: Constraint on test_db.orders.user_id uses ON DELETE CASCADE/), 'CASCADE action detected');

    # FK Type Mismatch Test
    %mock_queries = (
        'referential_constraints' => [],
        'COLUMN_NAME LIKE \'%_id\'.*COLUMN_NAME IS NULL' => [],
        'k.REFERENCED_TABLE_NAME IS NOT NULL.*c1.COLUMN_TYPE != c2.COLUMN_TYPE' => [
            "test_db\torders\tuser_id\tint(11)\tusers\tid\tbigint(20) unsigned", # Child int, Parent bigint
        ],
    );
    @main::generalrec = ();
    @mock_output = ();
    main::mysql_foreign_key_checks();
    ok(has_output(qr/BAD: FK Type Mismatch: test_db.orders.user_id \(int\(11\)\) -> users.id \(bigint\(20\) unsigned\)/), 'FK Data Type mismatch detected');
};

subtest 'Schema Sanitization' => sub {
    $main::myvar{'version'} = '8.0.30';
    %mock_queries = (
        'SUM\(CASE WHEN TABLE_TYPE = \'BASE TABLE\' THEN 1 ELSE 0 END\).*HAVING SUM' => [
            "empty_schema\t0\t0",
            "view_only_schema\t0\t5",
            "populated_schema\t10\t2", 
        ],
    );
    @main::generalrec = ();
    @mock_output = ();
    
    main::mysql_schema_sanitization();
    
    ok(has_output(qr/INFO: Schema empty_schema is empty \(no tables or views\)/), 'Empty schema detected');
    ok(has_output(qr/INFO: Schema view_only_schema contains only views \(5 views\)/), 'View-only schema detected');
    ok(has_output(qr/populated_schema/) == 0, 'Populated schema ignored');
};

subtest 'MySQL 8+ Specific Checks' => sub {
    $main::myvar{'version'} = '8.0.30';
    %mock_queries = (
        'DATA_TYPE = \'json\'' => [
            "test_db\tproducts\tattributes\tjson", # JSON without generated column
        ],
        'EXTRA LIKE \'%VIRTUAL%\'' => [], # No virtual columns found
        'IS_VISIBLE = \'NO\'' => [
            "test_db\tusers\tidx_email_invisible", # Invisible index
        ],
        'CONSTRAINT_TYPE = \'CHECK\'' => [
        ],
    );
    @main::generalrec = ();
    @mock_output = ();
    # Mocking mysql_version for MySQL 8 checks
    { no warnings 'redefine'; *main::mysql_version_ge = sub { 
        my ($major, $minor) = @_;
        return 1 if ($major || 0) >= 8;
        return 0;
    }};

    main::mysql_80_modeling_checks();
    
    ok(has_output(qr/INFO: Table test_db.products: JSON column 'attributes' detected without Virtual Generated Columns/), 'Unindexed JSON detected');
    ok(has_output(qr/INFO: Index test_db.users.idx_email_invisible is INVISIBLE/), 'Invisible index detected');
};

subtest 'Data Type Optimization Checks' => sub {
    $main::myvar{'version'} = '8.0.30';
    %mock_queries = (
        'IS_NULLABLE = \'YES\'' => [
            map { "test_db\ttable\tcol$_" } (1..25) # More than 20 nullable columns
        ],
    );
    @main::generalrec = ();
    @mock_output = ();
    
    main::mysql_datatype_optimization();
    
    ok(has_output(qr/INFO: There are 25 columns with NULL enabled/), 'Excessive nullable columns detected');
};

done_testing();
