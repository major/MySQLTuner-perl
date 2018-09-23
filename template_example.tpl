<!DOCTYPE html>
<html lang="en">
<head>
<!-- Required meta tags -->
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <title>MySQL Tuner report</title>
  
   <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css" integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO" crossorigin="anonymous">
  <link rel="stylesheet" href="//code.jquery.com/ui/1.12.1/themes/base/jquery-ui.css">

   <script src="https://code.jquery.com/jquery-3.3.1.slim.min.js" integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo" crossorigin="anonymous"></script>
   <script src="https://code.jquery.com/ui/1.12.0/jquery-ui.min.js" />

  <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js" integrity="sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49" crossorigin="anonymous"></script>

  <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js" integrity="sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy" crossorigin="anonymous"></script>

  <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>

<div class="container">
  <h3>MySQLTuner Report</h3>
 <div class="tabs">
    <ul>
      <li class="active"><a href="#home">Home</a></li>
      <li><a href="#debug">Debug</a></li>
  </ul>
    <div id="home" class="tab-pane fade active">
      <h3>Home</h3>
      <h5>Report date: </h5>
      <h5>Report host: </h5>
      <h5>Server version: </h5>
      <ul class="nav nav-tabs">
        <pre>{$data}</pre>
  </div>
    <div id="debug" class="tab-pane fade active">
      <h3>Raw Result Data Structure</h3>
      <h5>Report date: </h5>
      <h5>Report host: </h5>
      <h5>Server version: </h5>
      <ul class="nav nav-tabs">
        <pre>{$data}</pre>
  </div>
    <!--
    <div id="home" class="tab-pane fade in active">
      <h3>HOME</h3>
      <p>Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
    </div>
    <div id="menu1" class="tab-pane fade">
      <h3>Menu 1</h3>
      <p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.</p>
    </div>
    <div id="menu2" class="tab-pane fade">
      <h3>Menu 2</h3>
      <p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam.</p>
    </div>
    -->
  </div>
</div>
  <script>

 $( function() {
    $( "#tabs" ).tabs();
  } );
  </script>
</body>
</html>