// Promote an existing account (create it via the app's Sign Up first) to an admin role.
// Usage: node scripts/make_admin.js <email> [SUPER_ADMIN|MINE_ADMIN]
// Writes to the database in backend/.env (MONGODB_URI).
import "dotenv/config";
import mongoose from "mongoose";
import { UserModel } from "../src/Models/user.model.js";

const [email, role = "SUPER_ADMIN"] = process.argv.slice(2);
if (!email || !["SUPER_ADMIN", "MINE_ADMIN"].includes(role)) {
  console.error("Usage: node scripts/make_admin.js <email> [SUPER_ADMIN|MINE_ADMIN]");
  process.exit(1);
}

await mongoose.connect(process.env.MONGODB_URI);
try {
  const user = await UserModel.findOneAndUpdate({ email }, { role }, { new: true });
  if (!user) {
    console.error(`No account with email ${email}. Sign up in the app first.`);
    process.exitCode = 1;
  } else {
    console.log(`${user.email} is now ${user.role}. Log out and log in again to use admin screens.`);
  }
} finally {
  await mongoose.disconnect();
}
