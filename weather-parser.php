#!/usr/bin/env php
<?php

$configFile = '/etc/weather-parser.conf';
if (!file_exists($configFile)) {
    fwrite(STDERR, "Configuration file not found at $configFile\n");
    exit(1);
}

$config = parse_ini_file($configFile);
date_default_timezone_set($config['TIMEZONE'] ?? 'US/Eastern');

$lat = $config['LATITUDE'] ?? '40.869';
$lon = $config['LONGITUDE'] ?? '-73.5295';
$outputDir = rtrim($config['OUTPUT_DIR'] ?? '/var/www/weather', '/');
$url = "https://forecast.weather.gov/MapClick.php?lat={$lat}&lon={$lon}&unit=0&lg=english&FcstType=dwml";

class dwml_parser {
    private $url;
    private $rawXML;

    private function object2array($object) { return @json_decode(@json_encode($object),1); }
    
    public function __construct($url){
        $this->url = $url;
    }

    public function get_url(){
        $context = stream_context_create([
            "http" => [
                "header" => "User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36"
            ]
        ]);
        $this->rawXML = @file_get_contents($this->url, false, $context);
        return !empty($this->rawXML);
    }
    
    public function get_forecast(){
        if (strpos($this->rawXML, '<data type="forecast">') === false) return '';
        return explode('</data>', explode('<data type="forecast">', $this->rawXML)[1])[0];
    }
    
    public function get_location(){
        return explode('</location>', explode('<location>', $this->get_forecast())[1])[0];
    }
    
    public function array_location(){
        return $this->object2array(simplexml_load_string('<xml>'.$this->get_location().'</xml>'));
    }
    
    public function get_day_name_array($layoutKey){
        if (strpos($this->get_forecast(), '<layout-key>'.$layoutKey) === false) return [];
        $xml = explode('</time-layout>', explode('</layout-key>', explode('<layout-key>'.$layoutKey, $this->get_forecast())[1])[1])[0];
        $array = preg_split("/\r\n|\n|\r/", trim($xml));
        $output = [];
        foreach($array as $line){
            if (strpos($line, 'period-name="') !== false) {
                $output[] = explode('"', explode('period-name="', $line)[1])[0];
            }
        }
        return $output;
    }
    
    public function get_temperature_array($layoutKey){
        if (strpos($this->get_forecast(), 'time-layout="'.$layoutKey.'">') === false) return [];
        $xml = explode('</temperature>', explode('</name>', explode('time-layout="'.$layoutKey.'">', $this->get_forecast())[1])[1])[0];
        $array = preg_split("/\r\n|\n|\r/", trim($xml));
        $output = [];
        foreach($array as $line){
            if (strpos($line, '<value>') !== false) {
                $output[] = explode('</value>', explode('<value>', $line)[1])[0];
            }
        }
        return $output;
    }
    
    public function array_temperature(){
        $array1name = $this->get_day_name_array('k-p24h-n7-1');
        $array1temp = $this->get_temperature_array('k-p24h-n7-1');
        $array2name = $this->get_day_name_array('k-p24h-n7-2');
        $array2temp = $this->get_temperature_array('k-p24h-n7-2');
        $output = [];
        foreach($array1name as $key=>$value){
            if(isset($array1temp[$key])) $output[] = [$array1name[$key] => $array1temp[$key]];
            if(isset($array2name[$key])) $output[] = [$array2name[$key] => $array2temp[$key]];
        }
        return $output;
    }
    
    public function get_weather_array(){
        $xml = explode('</weather>', explode('</name>', explode('<weather time-layout="k-p12h-', $this->get_forecast())[1])[1])[0];
        $array = preg_split("/\r\n|\n|\r/", trim($xml));
        $output = [];
        foreach($array as $line){
            if (strpos($line, '<weather-conditions weather-summary="') !== false) {
                $output[] = explode('"/>', explode('<weather-conditions weather-summary="', $line)[1])[0];
            }
        }
        return $output;
    }
    
    public function get_forecast_icons_array(){
        $xml = explode('</conditions-icon>', explode('</name>', explode('<conditions-icon type="forecast-NWS" time-layout="k-p12h-', $this->get_forecast())[1])[1])[0];
        $array = preg_split("/\r\n|\n|\r/", trim($xml));
        $output = [];
        foreach($array as $line){
            if (strpos($line, '<icon-link>') !== false) {
                $output[] = explode('</icon-link>', explode('<icon-link>', $line)[1])[0];
            }
        }
        return $output;
    }
    
    public function get_text_forecast_array(){
        $xml = explode('</wordedForecast>', explode('</name>', explode('<wordedForecast time-layout="k-p12h-', $this->get_forecast())[1])[1])[0];
        $array = preg_split("/\r\n|\n|\r/", trim($xml));
        $output = [];
        foreach($array as $line){
            if (strpos($line, '<text>') !== false) {
                $output[] = explode('</text>', explode('<text>', $line)[1])[0];
            }
        }
        return $output;
    }
    
    public function array_forecast(){
        $arrayName = $this->get_day_name_array("k-p12h-");
        $arraySummary = $this->get_weather_array();
        $arrayIcon = $this->get_forecast_icons_array();
        $arrayText = $this->get_text_forecast_array();
        $output = [];
        foreach($arrayName as $key=>$value){
            if(isset($arraySummary[$key]) && isset($arrayIcon[$key]) && isset($arrayText[$key])) {
                $output[] = [$arrayName[$key] => ['summary'=>$arraySummary[$key], 'icon'=>$arrayIcon[$key], 'text'=>$arrayText[$key]]];
            }
        }
        return $output;
    }
    
    public function display_all($date){
        $copyright = (date("Y") != 2021) ? '2021-'.date("Y") : '2021';
        $locationDesc = $this->array_location()['description'] ?? 'Local';
        
        $header = '<!doctype html>
<HTML lang="en">
    <HEAD>
        <TITLE>Local Weather Forecast - '.$locationDesc.'</TITLE>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script>
            function checkLastUpdate() {
                const xhttp = new XMLHttpRequest();
                xhttp.onload = function() {
                    if (this.responseText.trim() !== "'.$date.'") {
                        location.reload();
                    }
                }
                xhttp.open("GET", "lastUpdate", true);
                xhttp.send();
            }
            setInterval(checkLastUpdate, 10000);
        </script>
        <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css">
    </HEAD>
    <BODY><div class="container text-center mt-4">
        <h2>Local Weather Forecast - '.$locationDesc.'</h2>
        <table class="table table-bordered mt-3">';
                
        $footer = '</table>
        <p class="mt-3">Generated from <a href="'.$this->url.'" target="_blank">'.explode("/", $this->url)[2].'</a>: '.date("M j, Y H:i:s T").'</p>
        <p>&copy;'.$copyright.' Gregory Pocali</p>
    </div></BODY></HTML>';

        $output = $header;
        foreach($this->array_forecast() as $line){
            $k = key($line);
            $output .= '<tr><td align="center"><h3>'.$k.'</h3></td><td><img src="'.$line[$k]['icon'].'" /></td><td>'.$line[$k]['text'].'</td></tr>';
        }
        $output .= $footer;
        return $output;
    }
}

// Runtime Service Loop Execution
while (true) {
    $dwml = new dwml_parser($url);
    if ($dwml->get_url()) {
        $lines = $dwml->array_forecast();
        $output = [];
        $index = 0;
        
        foreach($lines as $line){
            if($index > 1){ break; }
            $k = key($line);
            $output[$index] = $k.' Forecast.....';
            $prefixLength = strlen($output[$index]);
            foreach(explode(" ", $line[$k]['text']) as $word){
                if(strlen($output[$index])+strlen($word) >= 155){
                    $output[$index] .= "\n";
                    $index++;
                    $output[$index] = str_pad("", $prefixLength, " ");
                }
                $output[$index] .= " ".str_replace('%', '\%', $word);
            }
            $output[$index] .= "\n";
            $index++;
        }

        $date = date("Y-m-d H:i:s T");

        if (!is_dir($outputDir)) {
            mkdir($outputDir, 0755, true);
        }

        file_put_contents("$outputDir/nvr-display.txt", implode("", $output));
        file_put_contents("$outputDir/index.html", $dwml->display_all($date));
        file_put_contents("$outputDir/lastUpdate", $date);
    }
    
    // Sleep for 10 minutes (600 seconds)
    sleep(600);
}
?>