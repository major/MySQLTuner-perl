<?php
/**
 * MySQLTuner Documentation Site - PHP Edition
 * Main entry point and router.
 */

require_once 'includes/Parsedown.php';

$valid_pages = [
    'overview' => 'docs/overview.md',
    'usage' => 'docs/usage.md',
    'internals' => 'docs/internals.md',
    'mysql_support' => 'docs/mysql_support.md',
    'mariadb_support' => 'docs/mariadb_support.md',
    'releases' => 'docs/releases/index.md',
    'faq' => 'docs/faq.md'
];

$page = $_GET['p'] ?? 'home';

// --- Robust Routing (Pretty URLs fallback) ---
$request_uri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($request_uri, PHP_URL_PATH);
$path = trim($path, '/');

if ($page === 'home' && !empty($path)) {
    // Check if the path directly matches a valid page
    if (isset($valid_pages[$path])) {
        $page = $path;
    } else {
        // Handle sub-parts (e.g., /docs/overview)
        $parts = explode('/', $path);
        $last_part = end($parts);
        if (isset($valid_pages[$last_part])) {
            $page = $last_part;
        }
    }
}
$is_home = ($page === 'home');

// --- Remote Version Sync ---
$version_file = 'CURRENT_VERSION.txt';
$remote_version_url = 'https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/refs/heads/master/CURRENT_VERSION.txt';

// Read local version
$current_version = file_exists($version_file) ? trim(file_get_contents($version_file)) : 'Unknown';

// Force refresh if it looks like a placeholder or is too old
$force_refresh = ($current_version === 'Unknown' || $current_version === '1.0.4'); // 1.0.4 seems to be a sticky local placeholder
if ($force_refresh || !file_exists($version_file) || (time() - filemtime($version_file) > 3600)) {
    $remote_version = @file_get_contents($remote_version_url);
    if ($remote_version) {
        $remote_version = trim($remote_version);
        if ($remote_version !== $current_version) {
            file_put_contents($version_file, $remote_version);
            $current_version = $remote_version;
        }
    }
}

// Ensure includes have the expected variables
$current_page = $page;

// --- PHP-level redirect for index.html ---
if (strpos($_SERVER['REQUEST_URI'], '/index.html') !== false) {
    header("Location: /", true, 301);
    exit;
}

// Header
include 'includes/header.php';

// Sidebar
include 'includes/sidebar.php';
?>

<!-- Main Content Wrapper -->
<main id="main-content" style="flex: 1; min-width: 0;">

    <?php if ($is_home): ?>
        <!-- Landing Page Content -->
        <div id="home-view">
            <header class="hero">
                <div class="hero-bg"></div>
                <div class="hero-glow"></div>

                <nav class="container top-nav">
                    <div class="logo-wrap">
                        <img src="assets/img/mtlogo2.png" alt="Logo" style="height: 40px;">
                        <span style="font-family: var(--font-heading); font-weight: 800; font-size: 1.25rem;">MySQLTuner</span>
                    </div>
                    <div class="nav-actions">
                        <a href="/overview" class="btn btn-outline">Docs</a>
                        <a href="https://github.com/jmrenouard/MySQLTuner-perl" class="btn btn-primary">GitHub</a>
                    </div>
                </nav>

                <div class="container fade-in" style="text-align: center; padding: 10rem 1rem;">
                    <div class="badge">V<?php echo htmlspecialchars($current_version); ?> GA Available</div>
                    <h1 class="gradient-text" style="font-size: clamp(3rem, 10vw, 5.5rem); margin-bottom: 2rem;">
                        Database Tuning<br>Reimagined.
                    </h1>
                    <p style="font-size: 1.25rem; color: var(--text-muted); max-width: 750px; margin: 0 auto 3.5rem; line-height: 1.8;">
                        The gold standard advisor for MySQL, MariaDB, and Percona.
                        Gain deep insights with <span style="color: var(--accent-primary); font-weight: 600;">300+ performance indicators</span>
                        delivered in a zero-dependency Perl script.
                    </p>
                    <div style="display: flex; gap: 1.5rem; justify-content: center; flex-wrap: wrap;">
                        <a href="/overview" class="btn btn-primary">Start Optimizing</a>
                        <a href="/usage" class="btn btn-outline">How it works</a>
                    </div>
                </div>
            </header>

            <section class="container fade-in">
                <div class="grid grid-3">
                    <div class="card">
                        <div class="card-icon" style="color: var(--accent-primary);">⚡</div>
                        <h3>300+ Indicators</h3>
                        <p>Deep analysis spanning memory allocation, storage engines, security vulnerabilities, and performance schema.</p>
                    </div>
                    <div class="card">
                        <div class="card-icon" style="color: var(--accent-secondary);">🌐</div>
                        <h3>Universal Scope</h3>
                        <p>Optimized for everything from Legacy 5.5 to Modern 8.4+, including MariaDB 11.x and Cloud DBs (RDS, Azure, GCP).</p>
                    </div>
                    <div class="card">
                        <div class="card-icon" style="color: var(--accent-success);">🛠️</div>
                        <h3>Pure Portability</h3>
                        <p>Zero external CPAN dependencies. Execute instantly on any server with a base Perl installation.</p>
                    </div>
                </div>
            </section>

            <footer class="container" style="padding: 4rem 1.5rem; border-top: 1px solid var(--border-color); text-align: center; color: var(--text-muted); font-size: 0.9rem;">
                <p>© 2026 MySQLTuner Project. Released under GPLv3.</p>
            </footer>
        </div>
    <?php else: ?>
        <!-- Documentation View -->
        <div id="doc-view">
            <article class="container doc-content fade-in" style="padding: 6rem 1.5rem; max-width: 900px; margin: 0 auto;">
                <div id="doc-rendered-content">
                    <?php
                    if (isset($valid_pages[$page])) {
                        $md_file = 'public/' . $valid_pages[$page];
                        if (file_exists($md_file)) {
                            $Parsedown = new Parsedown();
                            echo $Parsedown->text(file_get_contents($md_file));
                        } else {
                            echo "<h1>404</h1><p>Documentation file not found.</p>";
                        }
                    } else {
                        echo "<h1>404</h1><p>Page not found.</p>";
                    }
                    ?>
                </div>
            </article>
        </div>
    <?php endif; ?>

</main>

<?php include 'includes/footer.php'; ?>
