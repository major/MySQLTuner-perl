<!doctype html>
<html lang="en">
  <head>
    <!-- Required meta tags -->
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

    <!-- Bootstrap CSS -->
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css" integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO" crossorigin="anonymous">

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


    /* /* Custom page CSS
    /*   -------------------------------------------------- */
    /*/* Not required for template or sticky footer method. */

    /*body > .container {
    /*  padding: 60px 15px 0;
    /*}

    /*.footer > .container {
    /*  padding-right: 15px;
    /*  padding-left: 15px;
    /*}

    /*code {
    /*  font-size: 80%;
    /*}*/
    .code-pre {
     background-color: #eee;
     padding: 1rem;
     font-size: 80%;
    }
    </style>
    <title>MySQL Tuner</title>
  </head>
  <body>
    <div class="container">
      <div class="pricing-header px-3 py-3 pt-md-5 pb-md-4 mx-auto text-center">
      <H1>MySQL Tuner</H1>
      </div>
      <ul class="nav nav-tabs" role="tablist">
        <li class="active" class="nav-item">
          <a class="nav-link" id="home-tab"  data-toggle="tab" role="tab" aria-controls="home" aria-selected="true" href="#home">Home</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" id="debug-tab" data-toggle="tab" role="tab" aria-controls="debug" aria-selected="false" href="#debug">Debug</a>
        </li>
      </ul>

      <div class="tab-content">
        <div id="home" class="tab-pane active">
          <h3>Home</h3>
          <h5>Report date: [% localtime %]</h5>
          <h5>Report host: [% $data{'Variables'}{'hostname'} %]</h5>
          <h5>Report OS: [% $data{'OS'}{'OS Type'} %], Architecture:[% $data{'OS'}{'Architecture'} %], Ram: [% $data{'OS'}{'Physical Memory'}{'pretty'} %]</h5>
          <h5>Server version: [% $data{'Variables'}{'version'} %], [% $data{'Variables'}{'version_compile_machine'} %], [% $data{'Status'}{'version_comment'} %]</h5>
          <hr/>
          <h3>Recommendations</h3>
          <ul>
            [%
            foreach $i ( @{$data{'Recommendations'}} ) {
              $OUT .= "<li>$i</li>";
            }
            %]
          </ul>
          <h3>Adjust variables</h3>
          <ul>
            [%
            foreach $i ( @{$data{'Adjust variables'}} ) {
              $OUT .= "<li>$i</li>";
            }
            %]
          </ul>
          <hr/>
        </div>
        <div id="debug" class="tab-pane">
          <h3>Raw Result Data Structure</h3>
          <pre class="code-pre"><code class="language-json" data-lang="json">[% $debug %]</code></pre>
          <hr/>
        </div>

      </div>

      <footer class="footer">
        <div class="container">
          <span class="text-muted">MySQL Tuner 1.7.13</span>
        </div>
      </footer>
    </div>
    <script src="https://code.jquery.com/jquery-3.3.1.slim.min.js" integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo" crossorigin="anonymous"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js" integrity="sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49" crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js" integrity="sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy" crossorigin="anonymous"></script>
  </body>
</html>
<!-- vim: set ft=html ts=2 sw=2 tw=999 et :-->
