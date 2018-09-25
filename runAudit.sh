#!/bin/bash

server=$1
_DIR=$(dirname `readlink -f $0`)

#SSH_OPTIONS="-i utilities/id_rsa"

SSH_OPTIONS="${SSH_OPTIONS:-""}

export SSH_CLIENT="ssh -q $SSH_OPTIONS -o TCPKeepAlive=yes -o ServerAliveInterval=50 -o strictHostKeyChecking=no"
export SCP_CLIENT="scp -q $SSH_OPTIONS -o TCPKeepAlive=yes -o ServerAliveInterval=50 -o strictHostKeyChecking=no"
 _DIR="$(dirname "`readlink -f $0`")"

echo "* CLEANUP OLD RESULT FILES"
rm -f mysqltuner_${server}.txt pt-*_${server}.txt innotop_${server}.txt

echo "* RUNNNING MYSQLTUNER"
$SSH_CLIENT root@${server} "mysqltuner --verbose --outputfile /tmp/mysqltuner_${server}.txt"
[ $? -ne 0 ] && exit 1

echo "* RUNNNING PERCONA SUMMARY"
$SSH_CLIENT root@${server} "pt-summary> /tmp/pt-summary_${server}.txt" 
[ $? -ne 0 ] && exit 1

echo "* RUNNNING PERCONA MYSQL SUMMARY"
$SSH_CLIENT root@${server} "pt-mysql-summary> /tmp/pt-mysql-summary_${server}.txt" 
[ $? -ne 0 ] && exit 1

echo "* RUNNNING INNOTOP"
$SSH_CLIENT root@${server} "innotop -C -d1 --count 5 -n>> /tmp/innotop_${server}.txt"
[ $? -ne 0 ] && exit 1

echo "* IMPORTING RESULT TXT"
$SCP_CLIENT root@${server}:/tmp/mysqltuner_${server}.txt .
$SCP_CLIENT root@${server}:/tmp/pt-*_${server}.txt .
$SCP_CLIENT root@${server}:/tmp/innotop_${server}.txt .
[ $? -ne 0 ] && exit 1

REPORT_NAME=audit.html
echo "* GENERATING HTML RESULT"
(
DATE="$(date)"
cat<<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>MySQL/MariaDB Audit report - $DATE</title>
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
  <link rel="stylesheet" href="https://ajax.googleapis.com/ajax/libs/jqueryui/1.12.1/themes/smoothness/jquery-ui.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
<script src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.12.1/jquery-ui.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.4.0/Chart.bundle.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
  </head>
  <body>
	<h1>MySQL/MariaDB Audit report - $DATE</h1>
	<div id="tabs">
  <ul>
    <li><a href="#mysqltuner">Tuner</a></li>
    <li><a href="#pt-summary">Linux</a></li>
    <li><a href="#pt-mysql-summary">Percona</a></li>
    <li><a href="#innotop">InnoTop</a></li>
  </ul>
  <div id="mysqltuner">
  <pre>
EOF
) > ${REPORT_NAME}

perl ${_DIR}/txt2Html.pl - mysqltuner_${server}.txt >> ${REPORT_NAME}

(
cat << 'EOF'
</pre></div>
  <div id='pt-summary'>
  <pre>
EOF
) >> ${REPORT_NAME}

perl ${_DIR}/txt2Html.pl \# pt-summary_${server}.txt >> ${REPORT_NAME}
(
cat << 'EOF'
</pre></div>
  <div id='pt-mysql-summary'>
  <pre>
EOF
) >> ${REPORT_NAME}
perl ${_DIR}/txt2Html.pl \# pt-mysql-summary_${server}.txt >> ${REPORT_NAME}

(
cat << 'EOF'
</pre></div>
  <div id='innotop'>
  <pre>
EOF
) >> ${REPORT_NAME}

cat innotop_${server}.txt >> ${REPORT_NAME}
(
cat << 'EOF'
</pre></div>
</div>

<script>
$(function(){
  $('#tabs').tabs({ active: 0 });
});
</script>
</body>
</html>
EOF
) >> ${REPORT_NAME}
echo "* ALL IS OK"
exit 0