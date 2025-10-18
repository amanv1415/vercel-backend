const mongoose = require('mongoose');

const designSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100,
  },
  canvasData: {
    type: mongoose.Schema.Types.Mixed,
    required: true,
  },
  thumbnail: {
    type: String,
    default: '',
  },
}, { timestamps: true });

designSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Design', designSchema);
