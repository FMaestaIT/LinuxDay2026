<?php
// Rubrica di esempio per la demo LAMP. Le credenziali arrivano da config.php.
require __DIR__ . '/config.php';

mysqli_report(MYSQLI_REPORT_OFF);
$db = @new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($db->connect_errno) {
    http_response_code(500);
    error_log("rubrica: DB connection failed: " . $db->connect_error);
    exit("Errore: impossibile collegarsi al database.");
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['nome'])) {
    $stmt = $db->prepare('INSERT INTO contatti (nome, email) VALUES (?, ?)');
    $stmt->bind_param('ss', $_POST['nome'], $_POST['email']);
    $stmt->execute();
    header('Location: /');
    exit;
}

$contatti = $db->query('SELECT nome, email, creato_il FROM contatti ORDER BY id');
$host = htmlspecialchars(gethostname());
?>
<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8">
  <title>Rubrica - <?= $host ?></title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 640px; margin: 2rem auto; padding: 0 1rem; }
    table { width: 100%; border-collapse: collapse; }
    td, th { border-bottom: 1px solid #ddd; padding: .4rem; text-align: left; }
  </style>
</head>
<body>
  <h1>Rubrica</h1>
  <p>Server: <strong><?= $host ?></strong> · PHP <?= PHP_VERSION ?></p>
  <table>
    <tr><th>Nome</th><th>Email</th><th>Creato il</th></tr>
    <?php while ($c = $contatti->fetch_assoc()): ?>
      <tr>
        <td><?= htmlspecialchars($c['nome']) ?></td>
        <td><?= htmlspecialchars($c['email']) ?></td>
        <td><?= htmlspecialchars($c['creato_il']) ?></td>
      </tr>
    <?php endwhile; ?>
  </table>
  <h2>Aggiungi contatto</h2>
  <form method="post">
    <input name="nome" placeholder="Nome" required>
    <input name="email" type="email" placeholder="Email">
    <button>Salva</button>
  </form>
</body>
</html>
