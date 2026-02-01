<?php
// header.php
// $is_home should be inherited from index.php
if (!isset($is_home)) {
    $is_home = (!isset($_GET['p']) || $_GET['p'] === 'home');
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MySQLTuner | The Gold Standard Database Tuning Advisor</title>
    <meta name="description" content="Official documentation for MySQLTuner-perl. Optimize MySQL, MariaDB, and Percona Server with 300+ verified indicators.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Outfit:wght@600;800&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body class="<?php echo $is_home ? 'is-home' : 'is-docs'; ?>">
    <div id="app">
