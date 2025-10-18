const Design = require('../models/Design');

exports.getDesigns = async (req, res) => {
  try {
    const designs = await Design.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .select('-__v');
    
    res.json({ success: true, data: designs });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getDesignById = async (req, res) => {
  try {
    const design = await Design.findOne({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!design) {
      return res.status(404).json({ 
        success: false, 
        message: 'Design not found' 
      });
    }

    res.json({ success: true, data: design });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createDesign = async (req, res) => {
  try {
    const { title, canvasData, thumbnail } = req.body;
    
    const design = await Design.create({
      userId: req.user.id,
      title,
      canvasData,
      thumbnail: thumbnail || '',
    });

    res.status(201).json({ success: true, data: design });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateDesign = async (req, res) => {
  try {
    const { title, canvasData, thumbnail } = req.body;
    
    const design = await Design.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { title, canvasData, thumbnail },
      { new: true, runValidators: true }
    );

    if (!design) {
      return res.status(404).json({ 
        success: false, 
        message: 'Design not found' 
      });
    }

    res.json({ success: true, data: design });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteDesign = async (req, res) => {
  try {
    const design = await Design.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!design) {
      return res.status(404).json({ 
        success: false, 
        message: 'Design not found' 
      });
    }

    res.json({ success: true, message: 'Design deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
