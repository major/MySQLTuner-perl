<?php
/**
 * CRITICAL CLEANUP SCRIPT
 * This script is intended to be run once on the server to remove legacy artifacts.
 */

echo "<h1>MySQLTuner Deployment Cleanup</h1>";

$files_to_delete = ['index.html', 'src', 'main.js'];

foreach ($files_to_delete as $file) {
    if (file_exists($file)) {
        echo "Found legacy file/dir: $file... ";
        if (is_dir($file)) {
            // Simple recursive delete for directory
            $it = new RecursiveDirectoryIterator($file, RecursiveDirectoryIterator::SKIP_DOTS);
            $files = new RecursiveIteratorIterator($it, RecursiveIteratorIterator::CHILD_FIRST);
            foreach($files as $f) {
                if ($f->isDir()){
                    rmdir($f->getRealPath());
                } else {
                    unlink($f->getRealPath());
                }
            }
            if (rmdir($file)) {
                echo "<span style='color:green'>DELETED dir</span><br>";
            } else {
                echo "<span style='color:red'>FAILED to delete dir</span><br>";
            }
        } else {
            if (unlink($file)) {
                echo "<span style='color:green'>DELETED file</span><br>";
            } else {
                echo "<span style='color:red'>FAILED to delete file</span><br>";
            }
        }
    } else {
        echo "File not found: $file (OK)<br>";
    }
}

echo "<h2>Environment Audit</h2>";
echo "Server Software: " . $_SERVER['SERVER_SOFTWARE'] . "<br>";
echo "PHP Version: " . phpversion() . "<br>";
echo "mod_rewrite active: " . (function_exists('apache_get_modules') && in_array('mod_rewrite', apache_get_modules() ?: []) ? 'YES' : 'UNKNOWN') . "<br>";
echo "Current Directory: " . getcwd() . "<br>";
echo "Directory Listing:<pre>";
print_r(scandir('.'));
echo "</pre>";

echo "<br><a href='/'>Go to Root</a>";
?>
