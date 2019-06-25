import Foundation

internal extension UIView {
    static var exKey: UInt8 = 0
    
    func exImpl<T: ExProtocol>() -> T {
        if let ex = objc_getAssociatedObject(self, &UIView.exKey) as? T {
            return ex
        }
        
        let ex = T(view: self)
        objc_setAssociatedObject(self, &UIView.exKey, ex,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return ex
    }
    
    func showSpinnerIfNeed(spinner: inout UIActivityIndicatorView?) {
        if let _ = spinner {
            return
        }
        
        let spn = UIActivityIndicatorView(style: .gray)
        spinner = spn
        self.addSubview(spn)
        
        spn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spn.centerXAnchor.constraint(equalTo: centerXAnchor),
            spn.centerYAnchor.constraint(equalTo: centerYAnchor)])
        
        spn.startAnimating()
    }
    
    
    func hideSpinner(spinner: inout UIActivityIndicatorView?) {
        guard let spn = spinner else {
            return
        }
        
        spn.removeFromSuperview()
        spinner = nil
    }
}
