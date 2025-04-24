<?php
// HLTV Demo Ordner anzeige fШr Hardstyle-Esports.de (/home)

// Update 27.10.09 Daten werden in einem Multidimensionalen-Array gespeichert, sortiert und umgekehrt.
// Update 28.10.09 DateigrГсe wird nun mit angezeigt.
echo ("<html>");
echo ("<head>");
echo ("<meta HTTP-EQUIV='Content-Type' Content='text/html;Charset=Windows-1251'>");
//echo ("<META HTTP-EQUIV="Page-Enter" Content='BlendTrans(Duration=2.0)'>");
echo ("</head>");
echo ("<body bgcolor = 'white'>");

function format_size($size, $round = 0) {
    //Size must be bytes!
        $sizes = array('B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB');
	    for ($i=0; $size > 1024 && isset($sizes[$i+1]); $i++) $size /= 1024;
	        return round($size,$round)." ".$sizes[$i];
		}
		
		echo ("<img src=\"./hltv.jpg\">");
		echo ("<br>Здесь вы можете найти демки, записанные на сервере <a href='http://public.overpro.ru'>public.overpro.ru:27015!</a><br>");
		echo ("<br><a href='http://demo.overpro.ru/demos'>Вернуться к каталогу демок</a><br><br>");
		
		$path = "."; // folder
		$count = 0; // Arrays start 
		$chandle = 0; // boolean for tables
		
		if($dir=opendir($path))
		{
		    while($file=readdir($dir))
		        {
			        if (!is_dir($file) && $file != "." && $file != ".." && $file != "index.php" && $file != "hltv.jpg")
				        {
					            $tmpfilesize = filesize($file);
						    
						                $data[$count][year]     = substr($file,5,2); // position 11 because of: "warserver1-09...
								            $data[$count][month]     = substr($file,7,2);
									                $data[$count][day]         = substr($file,9,2);
											            $data[$count][hour]     = substr($file,11,2);
												                $data[$count][minute]     = substr($file,13,2);
															    $data[$count][map]		=substr($file,16,-8);
															                $data[$count][file]     = $file;
																	            $data[$count][size]     = format_size($tmpfilesize);
																		       
																		                $count++;
																				        }
																					    }
																					    closedir($dir);
																					    }
																					    sort($data);
																					    $data = array_reverse($data); 
																					    
																					    echo ("<table border=0 cellpadding=0 cellspacing=0>");
																					    echo ("<tr>");
																					    echo ("<td width=100>Дата</td>");
																					    echo ("<td width=100>Время</td>");
																					    echo ("<td width=100>Карта</td>");
																					    echo ("<td width=150>Размер</td>");
																					    echo ("<td>Ссылка</td>");
																					    echo ("</tr>");
																					    
																					    foreach($data as $field)
																					    {
																					        if ($chandle == 0)
																						    {
																						            echo ("<tr>");
																							            $chandle = 1;
																								        }
																									    else
																									        {
																										        echo ("<tr bgcolor=\"#00FFFF\">");
																											        $chandle = 0;
																												    }
																												        echo ("<td>$field[day].$field[month].$field[year]</td>");
																													    echo ("<td>$field[hour]:$field[minute]</td>");
																														echo ("<td>$field[map]</td>");
																														    echo ("<td>$field[size]</td>");
																														        echo ("<td><a href=\"$field[file]\">$field[file]</a></td>");
																															    echo ("</tr>");
																															    }
																															    
																															    echo ("</table>");
																															    echo ("<br><a href='http://demo.overpro.ru/demos'>Вернуться к каталогу демок</a><br><br>");
																															    echo ("</body>");
																															    echo ("</html>");
																															    ?> 