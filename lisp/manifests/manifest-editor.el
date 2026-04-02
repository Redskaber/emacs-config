;;; manifest-editor.el --- Editor module manifest -*- lexical-binding: t; -*-
;;; Commentary:
;;; Declarative module manifest for editor layer.
;;; Code:

(defconst my/editor-modules
  '((:name editor-basics
     :feature my/feature-editor
     :require editor-basics
     :init my/editor-basics-init)

    (:name editor-motion
     :feature my/feature-editor
     :require editor-motion
     :init my/editor-motion-init)

    (:name editor-selection
     :feature my/feature-editor
     :require editor-selection
     :init my/editor-selection-init)

    (:name editor-pairs
     :feature my/feature-editor
     :require editor-pairs
     :init my/editor-pairs-init)

    (:name editor-indent
     :feature my/feature-editor
     :require editor-indent
     :init my/editor-indent-init)

    (:name editor-format
     :feature my/feature-editor
     :require editor-format
     :init my/editor-format-init)

    (:name editor-whitespace
     :feature my/feature-editor
     :require editor-whitespace
     :init my/editor-whitespace-init)

    (:name editor-snippets
     :feature my/feature-editor
     :require editor-snippets
     :init my/editor-snippets-init)

    (:name editor-folding
     :feature my/feature-editor
     :require editor-folding
     :init my/editor-folding-init))
  "Declarative editor module specifications.")

(provide 'manifest-editor)
;;; manifest-editor.el ends here
