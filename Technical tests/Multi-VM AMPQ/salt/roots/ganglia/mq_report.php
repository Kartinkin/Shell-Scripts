<?php

function graph_mq_report ( &$rrdtool_graph ) {
    global $context,
           $cpu_user_color,
           $hostname,
           $range,
           $rrd_dir,
           $size,
           $strip_domainname;

    if ($strip_domainname) {
       $hostname = strip_domainname($hostname);
    }

    $rrdtool_graph['height'] += ($size == 'medium') ? 28 : 0;
    $title = 'RabbitMQ';
    if ($context != 'host') {
       $rrdtool_graph['title'] = $title;
    } else {
       $rrdtool_graph['title'] = "$hostname $title last $range";
    }
    $rrdtool_graph['lower-limit']    = '0';
    $rrdtool_graph['vertical-label'] = 'Messages in queue';
    $rrdtool_graph['extras']         = '--rigid';

    if($context != "host" ) {
        $series =
              "DEF:'num_nodes'='${rrd_dir}/mq_length.rrd':'num':AVERAGE "
            . "DEF:'mq_length'='${rrd_dir}/mq_length.rrd':'sum':AVERAGE "
            . "CDEF:'cmq_length'=mq_length,num_nodes,/ "
            . "AREA:'cmq_length'#$cpu_user_color:'User CPU' ";
    } else {
        $series =
              "DEF:'mq_length'='${rrd_dir}/mq_length.rrd':'sum':AVERAGE "
            . "AREA:'mq_length'#$cpu_user_color:'User CPU' ";
    }

    $rrdtool_graph['series'] = $series;

    return $rrdtool_graph;
}

?>
