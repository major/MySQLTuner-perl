<!DOCTYPE html>
<html lang="en">
<head>
<!-- Required meta tags -->
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
  		<title>MySQL Tuner</title>
		  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>

<style type="text/css" media="screen">
/* Sticky footer styles
-------------------------------------------------- */
html {
  position: relative;
  min-height: 100%;
}
body {
  /* Margin bottom by footer height */
  margin-bottom: 10px;
}
.footer {
  position: absolute;
  #margin-left: 5px;
  bottom: 0;
  width: 100%;
  /* Set the fixed height of the footer here */
  height: 30px;
  line-height: 30px; /* Vertically center the text there */
  background-color: #f5f5f5;
}


/* Custom page CSS
-------------------------------------------------- */
/* Not required for template or sticky footer method. */

body > .container {
  padding: 60px 15px 0;
}

.footer > .container {
  padding-right: 15px;
  padding-left: 15px;
}

code {
  font-size: 80%;
}
</style>
<script src="https://code.jquery.com/jquery-3.3.1.slim.min.js" integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js" integrity="sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49" crossorigin="anonymous"></script>

		<script src="https://cdn.plot.ly/plotly-latest.min.js"></script>

</head>

<body>
  <ul class="nav nav-tabs">
    <H1>MySQL Tuner</H1>
    <li class="active"><a data-toggle="tab" href="#home">Home</a></li>
    <li><a data-toggle="tab" href="#debug">Debug</a></li>
  </ul>

  <div class="tab-content">
    <div id="home" class="tab-pane active">
      <h3>Home</h3>
						<h5>Report date: </h5>
						<h5>Report host: </h5>
						<h5>Server version: </h5>
						<pre>{$data}</pre>
		  <hr/>
		 </div>
    <div id="debug" class="tab-pane fade">
     <h3>Raw Result Data Structure</h3>
					<h5>Report date: </h5>
					<h5>Report host: </h5>
					<h5>Server version: </h5>
					<pre>{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}{$data}
					{$data}
				{$data}</pre>
				<hr/>
    </div>
    
		</div>


    <footer class="footer">
      <div class="container">
      			<span class="text-muted">MySQL Tuner 1.7.13</span>
      </div>
    </footer>		


</body>
</html>