import axios from "axios";
//const apiUrl = "http://k8s-default-backserv-a10bbd9324-c9a0679ddf46d492.elb.us-east-1.amazonaws.com:8080/api/tasks";
const apiUrl = "http://back-service:8080/api/tasks"
console.log(apiUrl)
export function getTasks() {
    return axios.get(apiUrl);
}

export function addTask(task) {
    return axios.post(apiUrl, task);
}

export function updateTask(id, task) {
    return axios.put(apiUrl + "/" + id, task);
}

export function deleteTask(id) {
    return axios.delete(apiUrl + "/" + id);
}
