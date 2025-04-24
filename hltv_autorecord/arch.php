<?php
//error_reporting(E_ALL);
//set_time_limit(0);
$path = "/home/hlds/hlds_l/cstrike/demos";
$path2 = "/srv/http/demos";
//$to_dirs = array('www/overpro.ru/demos/mix1/','www/overpro.ru/demos/mix2/', 'www/overpro.ru/demos/mix3/', 'www/overpro.ru/demos/mix3/', 'www/overpro.ru/demos/mix4/','www/overpro.ru/demos/mix5/','www/overpro.ru/demos/mix6/') ;
$from_dirs = array('/pub/', '/demo/', '/MS/', '/MS2/', '/AIM1/', '/serva4ok/MIX1/', '/MIX1/');

$filesizes = array();
//первый проход запоминаем размеры
foreach($from_dirs as $from_dir)
	{
	$demos_dir = opendir($path.$from_dir);
	while (false!==($file=readdir($demos_dir)))
		{
		if ($file!='.'&&$file!='..'&&strpos($file,'.dem')!==false)
			{
			$fsize=filesize($path.$from_dir.$file);
			if ($fsize<50000000)
				{
				$filesizes[$file]=$fsize;
				}
			else{
	//			echo "<br/>bad file:",$file, ",  size = ", $fsize;
				}
			}
		}
	closedir($demos_dir);
	}
//echo date("h:i:s");
sleep(3);
clearstatcache ();
//второй проход пермещаем 
$i=0;
foreach($from_dirs as $from_dir)
	{
	$to_dir=$from_dirs[$i];
	$demos_dir = opendir($path.$from_dir);
	while (false!==($file=readdir($demos_dir)))
		{
		if ($file!='.'&&$file!='..'&&strpos($file,'.dem')!==false)
			{
			$fsize=0;
			$fsize=filesize($path.$from_dir.$file);
			if ($fsize<50000000)
				{
				if ($fsize==$filesizes[$file])
					{
					//echo "<br>Перемещаем файл ",$file," размер не изменился; было ",$filesizes[$file]," стало, ".$fsize,";";
					move_demo($file, $from_dir, $to_dir);
					}
				else
					{
					//echo "<br>","размер изменился у файла ", $file;
					}
				}
			else
				{
				//echo "<br/>bad file:",$file, ",  size = ", $fsize;
				}
			}
		}
	$i++;
	closedir($demos_dir);
	}

function move_demo($filename, $from_dir, $to_dir)
{
//echo $filename,"from ",$from_dir," to ",$to_dir,"<br>";
global $path, $path2;
if (file_exists($path2.$to_dir.$filename.".zip"))
	unlink($path2.$to_dir.$filename.".zip");
echo "$path$from_dir$filename\n";
echo "$path2$to_dir$filename\n\n";
$data = file_get_contents($path.$from_dir.$filename);
$gzdata = gzencode($data, 9);
unset($data);
$fp = fopen($path2.$to_dir.$filename.".zip", "xb+");
//$fp = fopen($path.$to_dir.$filename.".zip")
fwrite($fp, $gzdata);
unset($gzdata);
fclose($fp);
unlink($path.$from_dir.$filename);
}
?>