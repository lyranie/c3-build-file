module version;

const VERSION = "@@VERSION@@";
const AUTHOR  = "@@AUTHOR@@";

$exec(`echo "const GIT_HASH = \"$(git rev-parse HEAD)\";"`);
