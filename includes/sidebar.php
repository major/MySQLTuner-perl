<?php
// sidebar.php
// $current_page should be inherited from index.php as $page
$current_page = $page ?? ($_GET['p'] ?? 'home');

function is_active($route, $current_page) {
    return ($route === $current_page) ? 'active' : '';
}
?>
<aside class="sidebar glass">
    <a href="/" class="sidebar-brand">
        <img src="assets/img/mtlogo2.png" alt="Logo" style="width: 32px; height: 32px; border-radius: 8px;">
        <span>MySQLTuner</span>
    </a>
    <nav class="sidebar-nav">
        <div class="nav-group">
            <div class="nav-group-title">Get Started</div>
            <div class="nav-item"><a href="/" class="nav-link <?php echo is_active('home', $current_page); ?>">Introduction</a></div>
            <div class="nav-item"><a href="/overview" class="nav-link <?php echo is_active('overview', $current_page); ?>">Overview</a></div>
            <div class="nav-item"><a href="/usage" class="nav-link <?php echo is_active('usage', $current_page); ?>">Usage Guide</a></div>
        </div>

        <div class="nav-group">
            <div class="nav-group-title">Advanced</div>
            <div class="nav-item"><a href="/internals" class="nav-link <?php echo is_active('internals', $current_page); ?>">Technical Internals</a></div>
        </div>

        <div class="nav-group">
            <div class="nav-group-title">Compatibility</div>
            <div class="nav-item"><a href="/mysql_support" class="nav-link <?php echo is_active('mysql_support', $current_page); ?>">MySQL Support</a></div>
            <div class="nav-item"><a href="/mariadb_support" class="nav-link <?php echo is_active('mariadb_support', $current_page); ?>">MariaDB Support</a></div>
        </div>

        <div class="nav-group">
            <div class="nav-group-title">Resources</div>
            <div class="nav-item"><a href="/releases" class="nav-link <?php echo is_active('releases', $current_page); ?>">Release Notes</a></div>
            <div class="nav-item"><a href="/faq" class="nav-link <?php echo is_active('faq', $current_page); ?>">FAQ</a></div>
        </div>
    </nav>

    <div class="sidebar-footer">
        <a href="https://github.com/jmrenouard/MySQLTuner-perl" class="github-link">
            <svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"></path>
            </svg>
            Repository
        </a>
    </div>
</aside>
