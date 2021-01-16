'use strict';
document.addEventListener('DOMContentLoaded', function () {
	const formImage = document.getElementById('form_image');
    const formView = document.querySelector('.file_view');
    const noteArea = document.querySelector('#noteArea');
    const updateNote = document.getElementById('updateNote');
    const notesPage = document.getElementById('notes-page');
    const createButton = document.getElementById('createButton');
    const saveButton = document.getElementById('saveNote');
    const deleteButton = document.getElementById('deleteNote');
    let selectedNote = undefined;
    let imageFile = undefined;
    let rawNotes = {};
    // {
    //     id: {
    //         raw_text: ...,
    //     }
    // }


    sendRequest('GET', '/notes')           // Get existing notes
        .then(notes => notes.json())
        .then(notes => {
            for (let i = 0; i < notes.length; i++){
                rawNotes[notes[i].id] = {
                    'raw_text': notes[i].raw_text
                };
            }
            createListOfNotes(notes);
        })
        .then(() => {
            if (/\/notes\/[0-9a-f]{16}/.test(window.location.pathname)) {
                slideToLeft();
                let id = window.location.pathname.match(/\/notes\/([0-9a-f]{16})/);
                selectedNote = document.getElementById(id[1]);
                sendRequest('GET', '/notes/'+id[1]+'/image') //TODO hadle when image does not exist
                    .then(resp => (resp.ok)
                        ? resp.blob().then(image => {
                        imageFile = image;
                        uploadFile(image);
                    })
                    : Promise.reject('image does not exist')
                    )       
                    .catch((err) => {
                        console.warn(err)
                    });
            }
        });

    function createListOfNotes (notes) {
        for (let i = 0; i < notes.length; i++) {
            const note = notes[i];
            createNoteElement(note);
        }
    }

    function createNoteElement (note) {
        const noteElement = document.createElement('li');
        noteElement.id = note.id;
        if (note.image === 1) {
            noteElement.dataset.image = 1;
        } else {
            noteElement.dataset.image = 0;
        }
        const textElement = document.createElement('p');
        textElement.appendChild(document.createTextNode(note.note_text));
        noteElement.appendChild(textElement);
        noteElement.addEventListener('click', selectNote, false);
        noteArea.appendChild(noteElement);
        noteArea.scrollTop = noteArea.scrollHeight;
    }

    function updateNoteElement (note, seLnote) {
        seLnote.innerHTML = '';
        if (note.image === 1) {
            seLnote.dataset.image = 1;
        } else {
            seLnote.dataset.image = 0;
        }
        const textElement = document.createElement('p');
        textElement.appendChild(document.createTextNode(note.note_text));
        seLnote.appendChild(textElement);
        selectedNote = undefined;
    }

   	function slideToLeft(event) {
    	notesPage.style.left = 0 + '%';
		notesPage.style.width = 30 + '%';
		updateNote.style.top = 14 + '%';
        updateNote.style.visibility = 'visible';
		createButton.classList.add('hidden');
    }
    function slideToMiddle(event) {
    	notesPage.style.left = 30 + '%';
		notesPage.style.width = 39 + '%';
		updateNote.style.top = 100 + '%';
        updateNote.style.visibility = 'hidden';
		createButton.classList.remove('hidden');
    }

    async function saveNote (event) {
        history.pushState(null, null, '/main');
        const noteText = noteInput.value;
        if (noteText === '') {
            noteInput.classList.add('_error');
            return;
        } else {
            noteInput.classList.remove('_error');
        }

        let noteForm = new FormData();
        noteForm.append('note_text', noteText);

        if (imageFile != undefined) {
            noteForm.append('image', imageFile);
        }

        if (selectedNote != undefined) {                        //if we select note
            //noteForm.append('id', selectedNote.id);
            sendRequest('PUT', '/notes/'+ selectedNote.id +'/update', noteForm)
                .then(updatedNote => updatedNote.json())
                .then(updatedNote => {
                    rawNotes[updatedNote.id] = {
                        raw_text: updatedNote.raw_text
                    };
                    updateNoteElement(updatedNote, selectedNote);
                });
        } else {                                               // if we create new
            sendRequest('POST', '/notes/create', noteForm)
                .then(newNote => newNote.json())
                .then(newNote => {
                    rawNotes[newNote.id] = {
                        raw_text: newNote.raw_text
                    };
                    createNoteElement(newNote);
                }); //TODO try catch
        }

        noteInput.value = '';
        formImage.value = '';
        formView.innerHTML = '';
        imageFile = undefined;
        slideToMiddle();
    } 

    async function deleteNote (event) {
        //form
        history.pushState(null, null, '/main');
        sendRequest('DELETE', '/notes/'+selectedNote.id+'/delete');
        selectedNote.parentNode.removeChild(selectedNote);
        delete rawNotes[selectedNote.id];

        selectedNote = undefined;
        noteInput.value = '';
        formImage.value = '';
        imageFile = undefined;
        formView.innerHTML = '';
        slideToMiddle();
    }

    async function sendRequest (method, url, noteForm) {
        let param = {
            method: method,
            credentials: "include"
        };
        if (method != 'GET') {
            param.body = noteForm;
        }
        let response = await fetch(url, param);
        return response;
    }

	async function selectNote(e){
        formImage.value = '';
        formView.innerHTML = '';
        imageFile = undefined;
		slideToLeft();
		selectedNote = e.currentTarget;
  		noteInput.value = rawNotes[selectedNote.id].raw_text;

        if (selectedNote.dataset.image != 0) {
            sendRequest('GET', '/notes/'+selectedNote.id+'/image')
                .then(image => image.blob())
                .then(image => {
                    imageFile = image;
                    uploadFile(image);
                });
        }
        history.pushState(null, null, '/notes/'+selectedNote.id);
	}

    function uploadFile (file) {
        if (!['image/jpeg', 'image/png', 'image/gif'].includes(file.type)) {
            alert("Разрешены только изображения.");
            formImage.value = ''; 
            return;
        }
        if (file.size > 10 * 1024 *1024) {
            alert("Файл должен быть менее 10мб");
            return;
        }
        let reader = new FileReader();

        reader.onload = function (e) {
            formView.innerHTML = `<img src="${e.target.result}" alt="фото">`;
        };
        reader.onerror = function (e) {
            alert("Ошибка");
        };
        reader.readAsDataURL(file);
    }

    deleteButton.addEventListener('click', deleteNote, false);
    saveButton.addEventListener('click', saveNote, false);
    createButton.addEventListener('click', slideToLeft, false);
    formImage.addEventListener('change', () => {
        imageFile = formImage.files[0];
        uploadFile(formImage.files[0]);
    });

});