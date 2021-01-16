'use strict';
document.addEventListener('DOMContentLoaded', function () {

    const authForm = document.getElementById('authForm');
    authForm.addEventListener('submit', sendAuthForm);

    function sendAuthForm(event){
        let error = formValidate(authForm);
        let formData = new FormData(authForm);

        if (error != 0) {
            event.preventDefault();
        }
        return;
    }

    function formValidate(form){
        let error = 0;
        let formReq = document.querySelectorAll('._req');

        for (let i = 0; i < formReq.length; i++) {
            const input = formReq[i];
            formRemoveError(input);
            if (input.classList.contains('_email') && input.value != '') {
                if (emailValidate(input)) {
                    formAddError(input);
                    error++;
                }
            } else if (input.classList.contains('_login')) {
                if (loginValidate(input)) {
                    formAddError(input);
                    error++;
                }
            } else {
                if (input.value === '' && !input.classList.contains('_email')){
                    formAddError(input);
                    error++;
                }
            }
        }

        let passInp = document.querySelector('._password');
        let conf_passInp = document.querySelector('._conf_password');
        if (passInp && conf_passInp) {
            let pass = passInp.value;
            let conf_pass = conf_passInp.value;

            if (pass && conf_pass && pass != conf_pass) {
                Toast.add({
                    text: 'Passwords must match',
                    color: '#FF000F',
                    autohide: true,
                    delay: 5000
                });
                formAddError(passInp);
                formAddError(conf_passInp);
                error++;
            }
        }
        return error;
    }

    function formRemoveError(input) {
        input.classList.remove('_error');
    }

    function formAddError(input) {
        input.classList.add('_error');
    }
    function emailValidate(input) {
        return !/^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,8})+$/.test(input.value);
    }
    function loginValidate(input) {
        return !/^[a-zA-Z]+$/.test(input.value);
    }
});
