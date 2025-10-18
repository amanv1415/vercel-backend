const express = require('express');
const { body } = require('express-validator');
const { protect } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const {
  getDesigns,
  getDesignById,
  createDesign,
  updateDesign,
  deleteDesign,
} = require('../controllers/designController');

const router = express.Router();

router.use(protect);

router.get('/', getDesigns);
router.get('/:id', getDesignById);

router.post('/', [
  body('title').trim().isLength({ min: 1, max: 100 }).withMessage('Title required'),
  body('canvasData').isObject().withMessage('Canvas data must be an object'),
  validate,
], createDesign);

router.put('/:id', [
  body('title').optional().trim().isLength({ min: 1, max: 100 }),
  body('canvasData').optional().isObject(),
  validate,
], updateDesign);

router.delete('/:id', deleteDesign);

module.exports = router;
