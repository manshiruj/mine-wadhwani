import MineModel from "../Models/mine.model.js";

// MINE_ADMIN only sees their own mine; others may filter with ?mine_name=.
export const mineScope = async (req) => {
  if (req.user.role === "MINE_ADMIN" && req.user.mineid) {
    const mine = await MineModel.findById(req.user.mineid).lean();
    if (mine) return { mine_name: mine.name };
  }
  return req.query.mine_name ? { mine_name: req.query.mine_name } : {};
};
