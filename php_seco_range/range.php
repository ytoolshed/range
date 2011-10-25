<?PHP
// Author eam@yahoo-inc.com
// This is a crappy hack, don't actually use it

function expand_range($range) {
  $ret = array();
  $handle = fopen("http://range:9999/range/list?" . urlencode($range), "r");
  if ($handle) {
    while (!feof($handle)) {
      $buffer = fgets($handle, 4096);
      $buffer = rtrim($buffer);
      $ret[] = $buffer;
    }
  fclose($handle);
  }
  return $ret;
}

?>
