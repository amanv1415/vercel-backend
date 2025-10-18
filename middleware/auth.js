const { verifyToken } = require('../utils/jwt');

exports.protect = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({ 
        success: false, 
        message: 'Not authorized' 
      });
    }

    const decoded = verifyToken(token);
    req.user = { id: decoded.id };
    next();
  } catch (error) {
    res.status(401).json({ 
      success: false, 
      message: 'Invalid token' 
    });
  }
};
