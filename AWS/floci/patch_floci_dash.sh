#!/usr/bin/env bash
# patch-floci-dash.sh: parches para floci-dash
#  1) Organizacion: quitar barra final de la ruta
#  2) OUs: campos en mayuscula inicial (Name, Id, Arn)
#  3) Cuentas: campos en mayuscula inicial (Name, Id, Email, Status)
#  4) Cuentas: listar todas (sin filtrar por parentId)
#  5) SCPs: campos en mayuscula inicial (Name, Id, Description, AwsManaged)

sudo docker exec -i floci-dash node - <<'EOF'
const fs = require("fs");
const dir = "/app/dist/frontend/assets/";
const name = fs.readdirSync(dir).find(f => /^ServicePage-.*\.js$/.test(f));
if (!name) { console.log("ServicePage file not found"); process.exit(1); }
const F = dir + name;
if (!fs.existsSync(F + ".orig")) fs.copyFileSync(F, F + ".orig");
let s = fs.readFileSync(F, "utf8");

// Sustitucion de texto exacto (parches 1 y 4)
function replaceText(label, bad, good) {
  if (s.includes(bad)) { s = s.split(bad).join(good); console.log(label + ": patched"); }
  else console.log(label + ": " + (s.includes(good) ? "already patched" : "anchor not found"));
}

// Campos en minuscula -> mayuscula inicial, acotado a un bloque (parches 2, 3 y 5)
function capFields(label, start, end, fields) {
  const a = s.indexOf(start);
  if (a < 0) { console.log(label + ": anchor not found"); return; }
  const e = s.indexOf(end, a);
  if (e < 0) { console.log(label + ": end not found"); return; }
  const seg = s.slice(a, e);
  const re = new RegExp("\\bae\\.(" + fields + ")\\b", "g");
  const out = seg.replace(re, (m, k) => "ae." + k[0].toUpperCase() + k.slice(1));
  s = s.slice(0, a) + out + s.slice(e);
  console.log(label + ": " + (out === seg ? "already patched" : "patched"));
}

replaceText("1 org route",
  'i("/aws/organizations/")',
  'i("/aws/organizations")');

capFields("2 ous fields",
  'emptyMessage:"No OUs in this root"', "Failed to delete", "name|id|arn");

capFields("3 accounts fields",
  'emptyMessage:"No accounts"', "Failed to close", "name|id|email|status");

replaceText("4 accounts query",
  'queryFn:()=>t?i(`/aws/organizations/accounts?parentId=${t}`):i("/aws/organizations/accounts")',
  'queryFn:()=>i("/aws/organizations/accounts")');

capFields("5 scp fields",
  'headerTitle:"Service Control Policies"', "Failed to delete",
  "name|id|description|awsManaged");

fs.writeFileSync(F, s);
EOF