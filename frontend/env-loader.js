const dotenv = require('dotenv');
const path = require('path');

const envPath = path.resolve(__dirname, 'local/env');
dotenv.config({ path: envPath });

console.log(`Carregando variáveis de ${envPath}`);